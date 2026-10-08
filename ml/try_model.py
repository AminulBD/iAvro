"""Play with a trained model.

    python try_model.py --ckpt out/best.pt

At the prompt type some Bangla context, then `|`, then candidates to rank:
    > আমি ভাত | খাই খায় খাও
Or just context to see predicted next words:
    > আজকে আবহাওয়া
"""

import argparse

import sentencepiece as spm
import torch
import torch.nn.functional as F

from model import boundary_ids, load_checkpoint, score_candidates
from prepare_data import normalize
from train import pick_device


@torch.no_grad()
def next_words(model, sp, context, boundary, device, k=8, max_tokens=6):
    """Greedy-complete the k most likely word starts into whole words."""
    T = model.cfg.ctx
    ids = [sp.eos_id()] + [i for w in context for i in sp.encode(w)]
    ids = ids[-(T - max_tokens):]
    starts = torch.tensor([sp.id_to_piece(i).startswith("▁") and len(sp.id_to_piece(i)) > 1
                           for i in range(sp.get_piece_size())])
    logp = F.log_softmax(model(torch.tensor([ids], device=device))[0, -1].float(), -1).cpu()
    logp[~starts] = float("-inf")
    boundary = set(boundary)
    words = []
    for first in logp.topk(k).indices.tolist():
        seq = ids + [first]
        for _ in range(max_tokens - 1):
            nxt = model(torch.tensor([seq], device=device))[0, -1].argmax().item()
            if nxt in boundary:
                break
            seq.append(nxt)
        words.append(sp.decode(seq[len(ids):]))
    return words


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ckpt", default="out/best.pt")
    ap.add_argument("--data", default="data")
    ap.add_argument("--device", default="auto")
    args = ap.parse_args()

    device = pick_device(args.device)
    sp = spm.SentencePieceProcessor(model_file=f"{args.data}/bn.model")
    model = load_checkpoint(args.ckpt, device)
    boundary = boundary_ids(sp)
    print("context | candidates   (Ctrl-D to quit)")
    while True:
        try:
            line = normalize(input("> ")).strip()
        except EOFError:
            break
        context, _, cands = line.partition("|")
        context = context.split()
        if cands.strip():
            cands = cands.split()
            scores = score_candidates(model, sp, context, cands, boundary, device)
            for s, c in sorted(zip(scores, cands), reverse=True):
                print(f"  {s:8.2f}  {c}")
        else:
            print("  " + " / ".join(next_words(model, sp, context, boundary, device)))


if __name__ == "__main__":
    main()
