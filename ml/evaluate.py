"""Measure the model the way iAvro will use it.

    python evaluate.py --ckpt out/best.pt

1. Word-level perplexity on held-out text (lower is better).
2. Candidate ranking: for held-out words that have phonetic look-alikes in iAvro's
   dictionary (কথা / কোথা, শব্দ / সব্দ, দিন / দীন ...), how often does each method put the
   real word first, given the preceding words? Compared methods:
     unigram  - word frequency only (roughly what a context-free ranking can do)
     bigram   - frequency given the previous word (stupid backoff)
     tinygpt  - this model
   Ties count as misses, so a method only scores when it strictly prefers the right word.
"""

import argparse
import math
import random
import re
import sqlite3
from collections import Counter
from pathlib import Path

import numpy as np
import sentencepiece as spm
import torch
import torch.nn.functional as F

from model import boundary_ids, load_checkpoint, score_candidates
from prepare_data import normalize
from train import pick_device

KARS = set("ািীুূৃৄেৈোৌ")
HASANTA, NUKTA, O_KAR = "্", "়", "ো"
CONSONANTS = set(chr(c) for c in range(0x0995, 0x09BA)) | {"ড়", "ঢ়", "য়"}
# Letters that Avro phonetic input commonly confuses (one romanisation, several spellings).
CONFUSABLE = [
    ["ি", "ী"],            # ি ী
    ["ু", "ূ"],            # ু ূ
    ["ই", "ঈ"],            # ই ঈ
    ["উ", "ঊ"],            # উ ঊ
    ["শ", "ষ", "স"],  # শ ষ স
    ["ন", "ণ"],            # ন ণ
    ["জ", "য"],            # জ য
    ["য", "য়"],            # য য়
    ["র", "ড়"],            # র ড়
    ["ত", "ৎ"],            # ত ৎ
    ["ং", "ঙ"],            # ং ঙ
]
GROUP_OF = {}
for group in CONFUSABLE:
    for ch in group:
        GROUP_OF.setdefault(ch, set()).update(c for c in group if c != ch)
WORD = re.compile(r"^[ঀ-৿‌‍]+$")
STRIP = "।॥,.;:!?\"'()[]{}‘’“”-–—"


def words_of(line):
    return [w for w in (t.strip(STRIP) for t in line.split()) if w and WORD.match(w)]


def variants(word):
    out = set()
    for i, ch in enumerate(word):
        for alt in GROUP_OF.get(ch, ()):
            out.add(word[:i] + alt + word[i + 1 :])
        if ch == O_KAR:  # কোথা -> কথা
            out.add(word[:i] + word[i + 1 :])
        nxt = word[i + 1] if i + 1 < len(word) else ""
        if ch in CONSONANTS and nxt not in KARS and nxt not in (HASANTA, NUKTA):  # কথা -> কোথা
            out.add(word[: i + 1] + O_KAR + word[i + 1 :])
    out.discard(word)
    return out


def load_dictionary(path):
    db = sqlite3.connect(path)
    words = set()
    for (table,) in db.execute("SELECT name FROM sqlite_master WHERE type='table'"):
        columns = [row[1] for row in db.execute(f'PRAGMA table_info("{table}")')]
        if "Words" in columns:
            words.update(normalize(w) for (w,) in db.execute(f'SELECT Words FROM "{table}"') if w)
    return words


def word_perplexity(model, sp, val_bin, device, tokens=200_000):
    data = np.memmap(val_bin, dtype=np.uint16, mode="r")[: tokens + 1]
    T = model.cfg.ctx
    word_starts = torch.tensor([sp.id_to_piece(i).startswith("▁") for i in range(sp.get_piece_size())])
    nll, n_words = 0.0, 0
    with torch.no_grad():
        for s in range(0, len(data) - T - 1, T * 64):
            chunk = [data[i : i + T + 1] for i in range(s, min(s + T * 64, len(data) - T - 1), T)]
            xy = torch.from_numpy(np.stack(chunk).astype(np.int64))
            x, y = xy[:, :-1].to(device), xy[:, 1:].to(device)
            nll += F.cross_entropy(model(x).float().view(-1, model.cfg.vocab), y.reshape(-1), reduction="sum").item()
            n_words += word_starts[y.cpu()].sum().item()
    return math.exp(nll / max(n_words, 1))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ckpt", default="out/best.pt")
    ap.add_argument("--data", default="data")
    ap.add_argument("--dictionary", default="../Resources/database.db3")
    ap.add_argument("--cases", type=int, default=3000)
    ap.add_argument("--count-lines", type=int, default=2_000_000, help="train lines used for n-gram counts")
    ap.add_argument("--context-words", type=int, default=10)
    ap.add_argument("--device", default="auto")
    args = ap.parse_args()

    device = pick_device(args.device)
    data = Path(args.data)
    sp = spm.SentencePieceProcessor(model_file=str(data / "bn.model"))
    model = load_checkpoint(args.ckpt, device)
    boundary = boundary_ids(sp)

    print(f"word perplexity: {word_perplexity(model, sp, data / 'val.bin', device):.1f}")

    dictionary = load_dictionary(args.dictionary)
    print(f"dictionary: {len(dictionary):,} words")

    uni, prev_count, bi = Counter(), Counter(), Counter()
    with open(data / "train.txt", encoding="utf-8") as f:
        for n, line in enumerate(f):
            if n >= args.count_lines:
                break
            ws = ["<s>"] + words_of(line)
            uni.update(ws[1:])
            prev_count.update(ws[:-1])
            bi.update(zip(ws, ws[1:]))
    total, vocab = sum(uni.values()), len(uni) + 1

    def unigram(w):
        return math.log((uni[w] + 1) / (total + vocab))

    def bigram(prev, w):  # stupid backoff
        if bi[(prev, w)]:
            return math.log(bi[(prev, w)] / prev_count[prev])
        return math.log(0.4) + unigram(w)

    cases = []
    with open(data / "val.txt", encoding="utf-8") as f:
        for line in f:
            ws = words_of(line)
            for i, w in enumerate(ws):
                if w not in dictionary:
                    continue
                alts = sorted(variants(w) & dictionary)
                if alts:
                    cases.append((ws[max(0, i - args.context_words) : i], w, alts[:9]))
            if len(cases) >= args.cases * 5:
                break
    random.Random(0).shuffle(cases)
    cases = cases[: args.cases]
    print(f"ranking cases: {len(cases):,}")

    hits = {m: [0, 0] for m in ("unigram", "bigram", "tinygpt")}  # [top1, top3]
    for context, truth, alts in cases:
        cands = [truth] + alts
        prev = context[-1] if context else "<s>"
        results = {
            "unigram": [unigram(c) for c in cands],
            "bigram": [bigram(prev, c) for c in cands],
            "tinygpt": score_candidates(model, sp, context, cands, boundary, device),
        }
        for method, scores in results.items():
            better = sum(1 for s in scores[1:] if s >= scores[0])  # ties count against
            hits[method][0] += better == 0
            hits[method][1] += better < 3

    n = max(len(cases), 1)
    print(f"\n{'method':<10}{'top-1':>8}{'top-3':>8}")
    for method, (top1, top3) in hits.items():
        print(f"{method:<10}{top1 / n:>8.1%}{top3 / n:>8.1%}")
    print("\nExamples:")
    for context, truth, alts in cases[:5]:
        cands = [truth] + alts
        scores = score_candidates(model, sp, context, cands, boundary, device)
        ranked = [c for _, c in sorted(zip(scores, cands), reverse=True)]
        print(f"  …{' '.join(context[-4:])} [{truth}] -> {' / '.join(ranked[:4])}")


if __name__ == "__main__":
    main()
