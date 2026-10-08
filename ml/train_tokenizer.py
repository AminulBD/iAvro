"""Train a Bangla SentencePiece tokenizer and encode the corpus into token files.

    python train_tokenizer.py --vocab 16000

Output: data/bn.model, data/bn.vocab, data/train.bin, data/val.bin (uint16 token ids,
sentences separated by the eos token).
"""

import argparse
import itertools
import os
from pathlib import Path

import numpy as np
import sentencepiece as spm


def encode_file(sp, src, dst, batch=20_000):
    total = 0
    with open(src, encoding="utf-8") as f, open(dst, "wb") as out:
        lines = []

        def flush():
            nonlocal total
            ids = []
            for row in sp.encode(lines):
                ids.extend(row)
                ids.append(sp.eos_id())
            out.write(np.asarray(ids, dtype=np.uint16).tobytes())
            total += len(ids)
            lines.clear()

        for line in f:
            lines.append(line.rstrip("\n"))
            if len(lines) == batch:
                flush()
        if lines:
            flush()
    return total


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="data")
    ap.add_argument("--vocab", type=int, default=16000)
    ap.add_argument("--sample-sentences", type=int, default=5_000_000,
                    help="sentences sampled for tokenizer training (more needs more RAM)")
    args = ap.parse_args()
    data = Path(args.data)
    assert args.vocab < 65536, "token files are uint16"

    spm.SentencePieceTrainer.train(
        input=str(data / "train.txt"),
        model_prefix=str(data / "bn"),
        vocab_size=args.vocab,
        model_type="unigram",
        character_coverage=0.9995,
        byte_fallback=True,                 # never produce <unk> for rare characters
        split_digits=True,
        normalization_rule_name="identity",  # text is already normalized; NFKC would undo য়/ড়/ঢ়
        input_sentence_size=args.sample_sentences,
        shuffle_input_sentence=True,
        num_threads=os.cpu_count() or 4,
        pad_id=-1, unk_id=0, bos_id=1, eos_id=2,
    )

    sp = spm.SentencePieceProcessor(model_file=str(data / "bn.model"))
    for split in ("train", "val"):
        n = encode_file(sp, data / f"{split}.txt", data / f"{split}.bin")
        print(f"{split}: {n:,} tokens")

    with open(data / "val.txt", encoding="utf-8") as f:
        sample = [line.strip() for line in itertools.islice(f, 3)]
    words = sum(len(s.split()) for s in sample)
    tokens = sum(len(sp.encode(s)) for s in sample)
    print(f"~{tokens / max(words, 1):.2f} tokens per word on a val sample")
    print("example:", sp.encode(sample[0], out_type=str)[:20])


if __name__ == "__main__":
    main()
