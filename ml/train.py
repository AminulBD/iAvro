"""Train TinyGPT on the encoded corpus.

    python train.py --preset small --steps 40000
    python train.py --preset small --steps 40000 --resume     # continue from out/last.pt
    python train.py --preset tiny --steps 300 --batch 32       # smoke test on a laptop

Each step sees batch * 64 tokens, so the defaults (40k steps, batch 256) cover ~650M tokens.
"""

import argparse
import math
import time
from dataclasses import asdict
from pathlib import Path

import numpy as np
import sentencepiece as spm
import torch
import torch.nn.functional as F

from model import PRESETS, ModelConfig, TinyGPT


def pick_device(name):
    if name != "auto":
        return name
    if torch.cuda.is_available():
        return "cuda"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="data")
    ap.add_argument("--out", default="out")
    ap.add_argument("--preset", default="small", choices=sorted(PRESETS))
    ap.add_argument("--ctx", type=int, default=64)
    ap.add_argument("--steps", type=int, default=40_000)
    ap.add_argument("--batch", type=int, default=256)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--warmup", type=int, default=1_000)
    ap.add_argument("--eval-every", type=int, default=1_000)
    ap.add_argument("--eval-batches", type=int, default=20)
    ap.add_argument("--device", default="auto")
    ap.add_argument("--compile", action="store_true", help="torch.compile (CUDA only, faster)")
    ap.add_argument("--resume", action="store_true")
    ap.add_argument("--seed", type=int, default=1337)
    args = ap.parse_args()

    torch.manual_seed(args.seed)
    rng = np.random.default_rng(args.seed)
    device = pick_device(args.device)
    data = Path(args.data)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    vocab = spm.SentencePieceProcessor(model_file=str(data / "bn.model")).get_piece_size()
    cfg = ModelConfig(vocab=vocab, ctx=args.ctx, **PRESETS[args.preset])
    model = TinyGPT(cfg).to(device)
    opt = torch.optim.AdamW(model.parameters(), lr=args.lr, betas=(0.9, 0.95), weight_decay=0.1)
    start, best = 0, float("inf")

    if args.resume:
        ckpt = torch.load(out / "last.pt", map_location=device, weights_only=False)
        model.load_state_dict(ckpt["model"])
        opt.load_state_dict(ckpt["optimizer"])
        start, best = ckpt["step"] + 1, ckpt["best_val"]
        print(f"resumed at step {start}")

    print(f"device {device}, {model.num_params() / 1e6:.2f}M params, config {asdict(cfg)}")
    step_model = torch.compile(model) if args.compile and device == "cuda" else model
    # bf16 autocast on CUDA; MPS and CPU train in fp32 (fast enough at this size).
    use_amp = device == "cuda"

    splits = {s: np.memmap(data / f"{s}.bin", dtype=np.uint16, mode="r") for s in ("train", "val")}

    def batch(split):
        d = splits[split]
        idx = rng.integers(0, len(d) - cfg.ctx - 1, args.batch)
        x = np.stack([d[i : i + cfg.ctx] for i in idx]).astype(np.int64)
        y = np.stack([d[i + 1 : i + 1 + cfg.ctx] for i in idx]).astype(np.int64)
        return torch.from_numpy(x).to(device), torch.from_numpy(y).to(device)

    def loss_on(x, y):
        with torch.autocast("cuda", dtype=torch.bfloat16, enabled=use_amp):
            logits = step_model(x)
        return F.cross_entropy(logits.float().view(-1, cfg.vocab), y.view(-1))

    @torch.no_grad()
    def val_loss():
        model.eval()
        losses = [loss_on(*batch("val")).item() for _ in range(args.eval_batches)]
        model.train()
        return sum(losses) / len(losses)

    def lr_at(step):
        warm = min(1.0, (step + 1) / args.warmup)
        return args.lr * warm * (0.1 + 0.9 * 0.5 * (1 + math.cos(math.pi * min(step, args.steps) / args.steps)))

    def save(path, step):
        torch.save({"model": model.state_dict(), "optimizer": opt.state_dict(), "config": asdict(cfg),
                    "step": step, "best_val": best}, path)

    model.train()
    t0 = time.time()
    for step in range(start, args.steps + 1):
        for group in opt.param_groups:
            group["lr"] = lr_at(step)
        loss = loss_on(*batch("train"))
        opt.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        opt.step()

        if step % 100 == 0:
            dt = time.time() - t0
            t0 = time.time()
            print(f"step {step:6d}  loss {loss.item():.3f}  lr {lr_at(step):.2e}  {dt:.1f}s/100")
        if step % args.eval_every == 0 or step == args.steps:
            vl = val_loss()
            if vl < best:
                best = vl
                save(out / "best.pt", step)
            save(out / "last.pt", step)
            print(f"== step {step}  val loss {vl:.3f}  token ppl {math.exp(vl):.1f}  best {best:.3f}")


if __name__ == "__main__":
    main()
