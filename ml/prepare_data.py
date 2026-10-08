"""Download Bangla text, clean and dedupe it, and split it into train/val files.

Examples:
    python prepare_data.py --sources wikipedia sangraha --max-gb 2
    python prepare_data.py --files ~/corpora/bn.txt.xz ~/corpora/news.txt
    python prepare_data.py --sources wikipedia --max-gb 0.05   # quick smoke test

Output: data/train.txt and data/val.txt, one cleaned sentence per line.
"""

import argparse
import gzip
import hashlib
import lzma
import random
import re
import unicodedata
from pathlib import Path

# Hugging Face datasets with a Bangla split. Check the dataset pages if a name changes.
HF_SOURCES = {
    "wikipedia": dict(path="wikimedia/wikipedia", name="20231101.bn"),
    "sangraha": dict(path="ai4bharat/sangraha", data_dir="verified/ben"),
    # Gated: accept the terms on the dataset page, then run `huggingface-cli login`.
    "culturax": dict(path="uonlp/CulturaX", name="bn"),
}

# iAvro emits precomposed য় ড় ঢ় (see Sources/Engine/Suggestion.swift), but NFC
# decomposes them into base + nukta, so put them back together after normalizing.
RECOMPOSE = {"য়": "য়", "ড়": "ড়", "ঢ়": "ঢ়"}
BANGLA = re.compile(r"[ঀ-৿]")
SPACES = re.compile(r"\s+")
SENTENCE_END = re.compile(r"(?<=[।?!])\s+")  # split after । ? !
URL = re.compile(r"https?://|www\.")


def normalize(text):
    text = unicodedata.normalize("NFC", text)
    for decomposed, composed in RECOMPOSE.items():
        text = text.replace(decomposed, composed)
    return text


def clean(line, min_chars, min_bangla):
    line = SPACES.sub(" ", normalize(line)).strip()
    if len(line) < min_chars or URL.search(line):
        return None
    letters = sum(1 for c in line if not c.isspace())
    if not letters or len(BANGLA.findall(line)) / letters < min_bangla:
        return None
    return line


def hf_texts(key):
    from datasets import load_dataset

    for row in load_dataset(split="train", streaming=True, **HF_SOURCES[key]):
        yield row["text"]


def file_texts(path):
    path = str(Path(path).expanduser())
    opener = lzma.open if path.endswith(".xz") else gzip.open if path.endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8", errors="ignore") as f:
        yield from f


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sources", nargs="*", default=[], choices=sorted(HF_SOURCES))
    ap.add_argument("--files", nargs="*", default=[], help="local .txt / .txt.gz / .txt.xz files")
    ap.add_argument("--out", default="data")
    ap.add_argument("--max-gb", type=float, default=2.0, help="stop after this much clean text")
    ap.add_argument("--val-fraction", type=float, default=0.005)
    ap.add_argument("--min-chars", type=int, default=15)
    ap.add_argument("--min-bangla", type=float, default=0.7, help="min share of Bangla letters")
    args = ap.parse_args()
    if not args.sources and not args.files:
        ap.error("give --sources and/or --files")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    rng = random.Random(1234)
    seen = set()
    budget = int(args.max_gb * 1e9)
    written = kept = dupes = rejected = 0

    streams = [(s, hf_texts(s)) for s in args.sources] + [(f, file_texts(f)) for f in args.files]
    with open(out / "train.txt", "w", encoding="utf-8") as train, open(out / "val.txt", "w", encoding="utf-8") as val:
        for name, texts in streams:
            print(f"reading {name} ...")
            for text in texts:
                for raw in text.split("\n"):
                    for piece in SENTENCE_END.split(raw):
                        if not piece.strip():
                            continue
                        line = clean(piece, args.min_chars, args.min_bangla)
                        if line is None:
                            rejected += 1
                            continue
                        digest = int.from_bytes(hashlib.blake2b(line.encode(), digest_size=8).digest(), "little")
                        if digest in seen:
                            dupes += 1
                            continue
                        seen.add(digest)
                        (val if rng.random() < args.val_fraction else train).write(line + "\n")
                        written += len(line.encode()) + 1
                        kept += 1
                        if kept % 500_000 == 0:
                            print(f"  {kept:,} lines, {written / 1e9:.2f} GB")
                        if written >= budget:
                            break
                    if written >= budget:
                        break
                if written >= budget:
                    break
            if written >= budget:
                print("reached --max-gb")
                break

    print(f"kept {kept:,} lines ({written / 1e9:.2f} GB), dropped {dupes:,} duplicates, rejected {rejected:,}")


if __name__ == "__main__":
    main()
