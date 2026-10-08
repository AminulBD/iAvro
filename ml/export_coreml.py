"""Export a trained checkpoint to Core ML for iAvro.

    python export_coreml.py --ckpt out/best.pt

Output (in export/):
  BanglaLM.mlpackage   drag into Xcode; it is compiled to BanglaLM.mlmodelc in the bundle
  bn_tokenizer.json    SentencePiece pieces + scores for the Swift tokenizer, plus ids/shapes

The model takes a fixed batch of candidate rows and does the scoring itself, so Swift
gets back two small (N, T) arrays instead of N x T x vocab logits:

  inputs   ids, targets            int32 (N, T); targets[n][t] = ids[n][t + 1]
  outputs  token_logprobs          log P(targets[n][t] | ids[n][..t])
           boundary_logprobs       log P(a word ends after ids[n][t])

Score of a candidate occupying positions start..end-1 of row n:
  sum(token_logprobs[n][start-1 ..< end-1]) + boundary_logprobs[n][end-1]

Conversion runs on Linux or macOS; running the .mlpackage needs macOS.
"""

import argparse
import json
from pathlib import Path

import coremltools as ct
import numpy as np
import sentencepiece as spm
import torch

from model import boundary_ids, load_checkpoint


class Scorer(torch.nn.Module):
    def __init__(self, model, boundary, vocab):
        super().__init__()
        self.model = model
        mask = torch.zeros(vocab, dtype=torch.bool)
        mask[boundary] = True
        self.register_buffer("boundary_mask", mask)

    def forward(self, ids, targets):
        logp = torch.log_softmax(self.model(ids.long()).float(), dim=-1)
        token = logp.gather(-1, targets.long().unsqueeze(-1)).squeeze(-1)
        boundary = torch.logsumexp(logp.masked_fill(~self.boundary_mask, -1e4), dim=-1)
        return token, boundary


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ckpt", default="out/best.pt")
    ap.add_argument("--data", default="data")
    ap.add_argument("--out", default="export")
    ap.add_argument("--rows", type=int, default=10, help="candidates scored per call")
    ap.add_argument("--no-quantize", action="store_true", help="keep fp16 weights instead of int8")
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    sp = spm.SentencePieceProcessor(model_file=str(Path(args.data) / "bn.model"))
    model = load_checkpoint(args.ckpt).float()
    T, N = model.cfg.ctx, args.rows

    scorer = Scorer(model, boundary_ids(sp), model.cfg.vocab).eval()
    example = torch.zeros(N, T, dtype=torch.int32)
    traced = torch.jit.trace(scorer, (example, example))

    mlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(name="ids", shape=(N, T), dtype=np.int32),
                ct.TensorType(name="targets", shape=(N, T), dtype=np.int32)],
        outputs=[ct.TensorType(name="token_logprobs"), ct.TensorType(name="boundary_logprobs")],
        minimum_deployment_target=ct.target.macOS13,
        compute_precision=ct.precision.FLOAT16,
    )
    if not args.no_quantize:
        from coremltools.optimize.coreml import OpLinearQuantizerConfig, OptimizationConfig, linear_quantize_weights

        config = OptimizationConfig(global_config=OpLinearQuantizerConfig(mode="linear_symmetric"))
        mlmodel = linear_quantize_weights(mlmodel, config)
    mlmodel.short_description = "Bangla candidate scorer for iAvro"
    mlmodel.save(str(out / "BanglaLM.mlpackage"))

    tokenizer = {
        "type": "sentencepiece-unigram",
        "word_prefix": "▁",
        "unk_id": sp.unk_id(),
        "eos_id": sp.eos_id(),
        "rows": N,
        "ctx": T,
        "pieces": [[sp.id_to_piece(i), sp.get_score(i), int(sp.is_byte(i))] for i in range(sp.get_piece_size())],
    }
    with open(out / "bn_tokenizer.json", "w", encoding="utf-8") as f:
        json.dump(tokenizer, f, ensure_ascii=False)

    # Sanity check: PyTorch scores of the traced module vs. the original model.
    ids = torch.randint(3, model.cfg.vocab, (N, T), dtype=torch.int32)
    tok, bnd = traced(ids, torch.roll(ids, -1, 1))
    print(f"traced output shapes {tuple(tok.shape)} {tuple(bnd.shape)}")
    print(f"saved {out / 'BanglaLM.mlpackage'} and {out / 'bn_tokenizer.json'}")


if __name__ == "__main__":
    main()
