# Bangla language model for iAvro

A kit for training a small Bangla language model yourself and shipping it inside iAvro to
rank candidates by context, complete words and predict the next word. Everything runs
on‑device, so no typed text ever leaves the Mac.

- [1. The approach](#1-the-approach)
- [2. What you need](#2-what-you-need)
- [3. Roadmap](#3-roadmap)
- [4. Step by step](#4-step-by-step)
- [5. Choosing a model size](#5-choosing-a-model-size)
- [6. Putting it into iAvro](#6-putting-it-into-iavro)
- [7. Tips and troubleshooting](#7-tips-and-troubleshooting)
- [8. Resources](#8-resources)

---

## 1. The approach

**The model only ever sees Bangla.** iAvro already turns `kotha` into Bangla candidates
(কথা, কোথা, …) through `PhoneticEngine`, `Database`, `AutoCorrect` and the suffix logic.
The model's single job is to say how likely each candidate is after the words the user has
just typed. That is ordinary Bangla language modelling, which a tiny model does well.

```
keystrokes ──▶ PhoneticEngine + Database (existing) ──▶ up to 10 candidates
                                                            │
last committed Bangla words ──▶ TinyGPT (Core ML) ──────────┤ score each candidate
                                                            ▼
                     final = LM score − w₁·levenshtein + w₂·log(1 + user picks)
```

Why a tiny model trained from scratch, and not Llama, Gemma or Qwen:

| | Tiny Bangla GPT (this kit) | General LLM (0.5B+) |
|---|---|---|
| Size in the app | 5–20 MB | 300 MB – 2 GB |
| Latency per keystroke | ~1–3 ms (Neural Engine) | 30–200 ms per token |
| Tokens per Bangla word | ~1.2–1.5 (Bangla‑only vocabulary) | often 3–8 |
| Output | deterministic scores | generative, can drift |
| Can train it yourself | yes, one GPU, hours | no (fine‑tuning only) |

An LLM only makes sense later as a separate, opt‑in "rewrite this sentence" feature, never
on the per‑keystroke path.

## 2. What you need

**Skills:** basic Python and a terminal. You don't need ML experience; the scripts are short
and commented. Section 8 lists material if you want to understand the internals.

**Hardware (any one of these):**

| Option | Training time for `small` (40k steps) | Notes |
|---|---|---|
| NVIDIA GPU, 12 GB+ (RTX 3060/3090/4090) | ~1–3 h | best; add `--compile` |
| Apple Silicon Mac (M1–M4) | ~overnight | uses MPS; fine for this size |
| Free cloud: Kaggle (T4/P100, ~30 h/week), Google Colab | ~2–5 h | sessions time out; use `--resume` |
| Rented GPU: RunPod, Vast.ai, Lambda | ~1–2 h | cheapest way to iterate quickly |

These times are rough estimates. Measure your own from the `s/100` figure that `train.py` prints.

**Disk:** ~10 GB (raw text, cleaned text, token files, checkpoints).
**RAM:** 16 GB is comfortable. Tokenizer training and dedupe are the hungry parts.
**Software:** Python 3.10–3.12 recommended (coremltools may lag behind the newest Python
and PyTorch releases), plus `pip install -r requirements.txt`.

## 3. Roadmap

| Week | Goal | Done when |
|---|---|---|
| 1 | **Pipeline smoke test**: run every script on ~50 MB of text | `evaluate.py` prints a table |
| 1–2 | **Data**: collect and clean 1–3 GB of Bangla text | `data/train.txt` ready, spot‑checked by eye |
| 2 | **Tokenizer + first real run** with the `small` preset | val loss stops improving |
| 2–3 | **Evaluate**: TinyGPT clearly beats the bigram baseline on top‑1 | if not, fix the data first, then try `base` |
| 3–4 | **Swift integration** behind a "Smart ranking" preference, off by default | p95 latency < 5 ms, no crashes |
| 4+ | **Personal learning** (user picks), completion and next‑word prediction; tune weights | top‑1 gain measured on the test set |

Don't skip the smoke test. It catches environment problems in minutes instead of hours.

## 4. Step by step

All commands run inside `ml/`.

### 4.0 Set up

```sh
cd ml
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

### 4.1 Collect and clean data: `prepare_data.py`

```sh
# Smoke test (a few minutes)
python prepare_data.py --sources wikipedia --max-gb 0.05

# Real run: ~2 GB of clean text
python prepare_data.py --sources wikipedia sangraha --max-gb 2

# Add your own files (.txt, .txt.gz or .txt.xz; one document or sentence per line)
python prepare_data.py --sources wikipedia sangraha --files ~/corpora/cc100_bn.txt.xz --max-gb 3
```

What the script does:
- **Normalizes Unicode** to NFC, then recomposes য়, ড়, ঢ় into the single code points iAvro
  outputs. This matters: if training text and keyboard output spell the same word with
  different code points, the model can't recognise it.
- **Splits sentences** on । ? !, collapses whitespace, and drops lines that are too short,
  contain URLs, or are less than 70% Bangla letters.
- **Removes exact duplicates**, which are common in web text.
- **Holds out 0.5%** of sentences as `data/val.txt` for evaluation.

Open `data/train.txt` and read a few hundred random lines (`shuf -n 200 data/train.txt`).
If you see boilerplate ("সর্বস্বত্ব সংরক্ষিত", menus, ads), add a filter in `clean()`.
Data quality matters more than any model setting.

**Which text to use.** iAvro users type chats, social posts, emails and documents, so mix
formal text (Wikipedia, news, books) with informal text (web crawl). Wikipedia alone
makes the model formal and encyclopaedic. Section 8 lists the sources.

### 4.2 Train the tokenizer: `train_tokenizer.py`

```sh
python train_tokenizer.py --vocab 16000
```

This trains a SentencePiece unigram tokenizer (`data/bn.model`), then encodes the corpus into
`data/train.bin` and `data/val.bin`. Check the printed "tokens per word". For real Bangla
text with a 16k vocabulary it should be roughly 1.2–1.6.

- `--vocab 16000` is a good default. Use 8000 for the `tiny` preset, or 24000–32000 if you
  have more than 3 GB of text and use `base`.
- Normalization is deliberately disabled (`identity`). SentencePiece's default NFKC would undo
  the য়/ড়/ঢ় handling above.

### 4.3 Train: `train.py`

```sh
# Smoke test: a few minutes, even on CPU
python train.py --preset tiny --steps 300 --batch 32

# Real run
python train.py --preset small --steps 40000            # add --compile on NVIDIA GPUs
python train.py --preset small --steps 40000 --resume   # continue after an interruption
```

Every 1,000 steps it prints the validation loss and saves `out/last.pt`, plus `out/best.pt`
when validation loss improves. What to watch for:
- **Loss falls fast, then slowly.** That's normal. Stop early if val loss is flat for 5k+ steps.
- **Train loss far below val loss** means the model is memorising. Get more data, or use a
  smaller preset or fewer steps.
- **Loss becomes `nan`** means the learning rate is too high. Retry with `--lr 6e-4`.
- **Out of memory:** lower `--batch` to 128 or 64. Results barely change at this size.

The defaults (batch 256 × 64 tokens × 40k steps ≈ 650M tokens) train `small` well past the
"compute‑optimal" point. That's intentional: small models deployed on‑device benefit from
extra training, as in the TinyStories and Chinchilla papers.

### 4.4 Evaluate: `evaluate.py`

```sh
python evaluate.py --ckpt out/best.pt
```

It prints:
1. **Word perplexity** on held‑out text. Lower is better. Use it to compare runs that share
   the same tokenizer and data.
2. **A candidate ranking table.** This is the number that matters for iAvro. For held‑out words
   that have phonetic look‑alikes in iAvro's own dictionary (`Resources/database.db3`), it asks
   each method to pick the real word given the preceding words:

```
method      top-1   top-3
unigram      ...     ...    word frequency only, no context
bigram       ...     ...    previous word only
tinygpt      ...     ...    this model
```

Ship the model only if `tinygpt` clearly beats `bigram` on top‑1. If it doesn't, more and
cleaner data almost always helps more than a bigger model. The look‑alike sets come from
common Avro confusions (ি/ী, ু/ূ, শ/ষ/স, ন/ণ, জ/য, র/ড়, ত/ৎ, ং/ঙ, and an added or dropped ো). They
are a proxy; a final check should run the real iAvro pipeline (section 6).

### 4.5 Try it by hand: `try_model.py`

```sh
python try_model.py --ckpt out/best.pt
> আমি ভাত | খাই খায় খাও        # rank candidates after a context
> আজকের আবহাওয়া                 # predict next words
```

### 4.6 Export to Core ML: `export_coreml.py`

```sh
python export_coreml.py --ckpt out/best.pt
```

This writes:
- `export/BanglaLM.mlpackage`: an int8 model, about 9 MB for `small`. It takes a fixed batch of
  10 candidate rows × 64 tokens and returns per‑token and word‑end log‑probabilities. All the
  scoring maths happens inside the model, so Swift does very little.
- `export/bn_tokenizer.json`: the vocabulary pieces and scores for a Swift tokenizer, plus
  `eos_id`, `rows` and `ctx`.

Conversion works on Linux too, but you need macOS to run the model. If conversion fails with a
PyTorch version warning, install the PyTorch version that coremltools lists as tested.

### Running on Kaggle or Colab

```sh
!git clone https://github.com/AminulBD/iAvro && cd iAvro/ml && pip install -r requirements.txt
!cd iAvro/ml && python prepare_data.py --sources wikipedia sangraha --max-gb 2
!cd iAvro/ml && python train_tokenizer.py && python train.py --preset small --compile
```

Free sessions stop after a few hours. Save `ml/data/bn.model` and `ml/out/last.pt` to Drive or
Kaggle output, then continue with `--resume`.

## 5. Choosing a model size

| Preset | Layers × width | Params (16k vocab) | int8 size | Use when |
|---|---|---|---|---|
| `tiny` | 4 × 192 | ~4.9M | ~5 MB | first experiments; older Intel Macs |
| `small` | 6 × 256 | ~8.8M | ~9 MB | **recommended default** |
| `base` | 8 × 384 | ~20M | ~20 MB | if `small` plateaus and you have 2 GB+ of text |

The context is 64 tokens, roughly the last 8–10 words, which is all an input method needs.
A longer context makes every keystroke slower for little gain.

## 6. Putting it into iAvro

This is the plan for the Swift side; it's a separate change from training.

1. **Bundle the model.** Add `BanglaLM.mlpackage` and `bn_tokenizer.json` to the Xcode target
   (Resources). Xcode compiles the model to `BanglaLM.mlmodelc`.
2. **Tokenizer** (`Sources/Engine/BanglaTokenizer.swift`). SentencePiece splits on spaces first,
   so tokenize each word separately. Prefix the word with `▁`, then run a Viterbi search for the
   highest total score over pieces from `bn_tokenizer.json`, falling back to byte pieces for
   unknown characters. That's about 60–80 lines. Alternatively, use the `Tokenizers` module from
   Hugging Face's `swift-transformers` package.
3. **Model wrapper** (`Sources/Engine/LanguageModel.swift`):
   - Load the model once, lazily, with `MLModelConfiguration.computeUnits = .all`.
   - For each candidate `n`, build a row `[eos] + contextTokens + candidateTokens`. Trim the
     context from the left to fit 64 tokens, and set `targets[n][t] = ids[n][t+1]`. Leave unused
     rows and positions as zeros.
   - Run one prediction for all candidates. The score is the sum of
     `token_logprobs[n][t-1]` over the candidate's positions, plus
     `boundary_logprobs[n][last position]`. This is exactly what `score_candidates()` in
     `model.py` does, so use it as the reference implementation and compare numbers in a unit test.
4. **Context tracking** (`Sources/AvroKeyboardController.swift`). In `commit(_:)`, append the
   committed word to a ring buffer of the last ~8 words. Clear it on newline, focus loss or app
   switch. Never store it on disk.
5. **Re‑rank** (`Sources/Engine/Suggestion.swift`, `list(for:)`). After the dictionary lookup,
   reorder the dictionary candidates with
   `final = lm − w₁·levenshtein + w₂·log(1 + picks)`. Keep the auto‑correct entry and the plain
   transliteration where they are today. Skip the model when the context is empty or the
   preference is off. Tune `w₁` and `w₂` on the evaluation set.
6. **Preference.** Add a "Smart ranking (on‑device AI)" checkbox in `Preferences`, off by default
   for the first release.
7. **Completion and next word** (later). For a partial word, take dictionary words with that
   prefix and score them with the same call. For the next word, score frequent words after the
   context. No new model output is needed.
8. **Personal learning.** `CacheManager` already remembers picks. Persist pick counts locally and
   blend them in through `w₂`. Don't fine‑tune the network on the device.

Budget: p95 under 5 ms per keystroke for the full re‑rank. Run the model off the main thread and
keep the old order if a result arrives late.

## 7. Tips and troubleshooting

- **Data problems look like model problems.** If outputs look odd, read your training text first.
- **Keep the tokenizer fixed** once you start comparing models. Perplexity isn't comparable across
  tokenizers, though the ranking table is.
- **Set a seed** (`--seed`) and change one thing at a time. Write down every run's settings and
  results.
- **Licensing:** check each dataset's licence before shipping a model trained on it. Wikipedia is
  CC BY‑SA; Sangraha, CulturaX and CC‑100 each have their own terms. Credit them in the app's About
  window.
- **Privacy:** don't train on users' typing, and don't collect it. Personalization stays local.
- **`coremltools` errors:** use Python 3.10–3.12 and the newest PyTorch version that coremltools
  says it has tested. The model code avoids ops that convert poorly.
- **MPS errors on a Mac:** update PyTorch, or run with `--device cpu` to confirm the problem is
  specific to MPS.

## 8. Resources

### Bangla text data

| Source | What it is | How to get it |
|---|---|---|
| Bangla Wikipedia | ~150k+ articles, formal | `--sources wikipedia` ([wikimedia/wikipedia](https://huggingface.co/datasets/wikimedia/wikipedia), config `20231101.bn`) |
| AI4Bharat Sangraha | large cleaned Indic corpus; use the "verified" Bengali part | `--sources sangraha` ([ai4bharat/sangraha](https://huggingface.co/datasets/ai4bharat/sangraha)) |
| IndicCorp v2 | news‑heavy Indic corpus with a large Bangla part | [ai4bharat/IndicCorpV2](https://huggingface.co/datasets/ai4bharat/IndicCorpV2); download the `bn` file, then `--files` |
| CulturaX | cleaned mC4 + OSCAR, multilingual | `--sources culturax` (gated: accept the terms, then `huggingface-cli login`) |
| CC‑100 | web crawl, informal | [data.statmt.org/cc-100](https://data.statmt.org/cc-100/) → `bn.txt.xz`, then `--files` |
| OSCAR | web crawl | [oscar-project.org](https://oscar-project.org/) |
| Your own | books, news archives, public‑domain literature you have rights to | `--files` |

Dataset names and configs change over time. If a `--sources` name fails, check the dataset page.

### Learn how it works

- Andrej Karpathy, **"Let's build GPT: from scratch, in code, spelled out"** (YouTube). The
  model in `model.py` is the same idea at a smaller size.
- [karpathy/nanoGPT](https://github.com/karpathy/nanoGPT) and its successor
  [karpathy/nanochat](https://github.com/karpathy/nanochat): reference training code.
- Karpathy's **"Let's build the GPT Tokenizer"** (YouTube): how tokenizers work.
- Jay Alammar, **"The Illustrated Transformer"** and **"The Illustrated GPT‑2"**.
- Hugging Face **NLP Course**: tokenizers, datasets, training basics.

### Tools

- [SentencePiece](https://github.com/google/sentencepiece): tokenizer training and options.
- [PyTorch](https://pytorch.org/get-started/locally/): install instructions (CUDA, MPS).
- [Hugging Face Datasets](https://huggingface.co/docs/datasets): streaming large corpora.
- [coremltools](https://apple.github.io/coremltools/docs-guides/): PyTorch conversion and weight
  quantization guides.
- Apple, **"Deploying Transformers on the Apple Neural Engine"** and
  [apple/ml-ane-transformers](https://github.com/apple/ml-ane-transformers): making transformers
  fast on the Neural Engine.
- [huggingface/swift-transformers](https://github.com/huggingface/swift-transformers): Swift
  tokenizers and Core ML helpers.
- [KenLM](https://github.com/kpu/kenlm): a classic n‑gram toolkit, if you want a stronger
  non‑neural baseline.

### Papers worth skimming

- Vaswani et al., 2017, *Attention Is All You Need*: the transformer.
- Radford et al., 2019, *Language Models are Unsupervised Multitask Learners* (GPT‑2): the
  architecture used here.
- Kudo, 2018, *Subword Regularization* (the unigram tokenizer), and Kudo & Richardson, 2018,
  *SentencePiece*.
- Hoffmann et al., 2022, *Training Compute‑Optimal Large Language Models* (Chinchilla): how much
  data per parameter.
- Eldan & Li, 2023, *TinyStories*: how far very small models can go with good data.
- Kakwani et al., 2020 (IndicNLPSuite) and Doddapaneni et al., 2023 (IndicCorp v2): Indic corpora.
- Khan et al., 2024, *IndicLLMSuite*: the Sangraha corpus.
- Bhattacharjee et al., 2022, *BanglaBERT*: Bangla NLP resources and benchmarks.
- Hard et al., 2018, *Federated Learning for Mobile Keyboard Prediction* (Gboard): how a production
  keyboard uses a small language model.

## Files

| File | Purpose |
|---|---|
| `prepare_data.py` | download, clean, dedupe and split text |
| `train_tokenizer.py` | train SentencePiece and write token files |
| `model.py` | TinyGPT model, presets, candidate scoring (reference for Swift) |
| `train.py` | training loop with checkpoints and resume |
| `evaluate.py` | perplexity and candidate ranking vs. unigram/bigram baselines |
| `try_model.py` | interactive ranking and next‑word prediction |
| `export_coreml.py` | Core ML export and tokenizer JSON for iAvro |
