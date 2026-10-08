"""TinyGPT: a small decoder-only transformer that scores Bangla text.

Shared by train.py, evaluate.py, try_model.py and export_coreml.py.
"""

import math
from dataclasses import dataclass

import torch
import torch.nn as nn
import torch.nn.functional as F

# Approximate parameter counts assume a 16k vocabulary with tied embeddings.
PRESETS = {
    "tiny": dict(n_layer=4, n_head=4, d=192),   # ~4.9M params, fastest
    "small": dict(n_layer=6, n_head=4, d=256),  # ~8.8M params, recommended
    "base": dict(n_layer=8, n_head=6, d=384),   # ~20M params, if small plateaus
}


@dataclass
class ModelConfig:
    vocab: int = 16000
    ctx: int = 64
    n_layer: int = 6
    n_head: int = 4
    d: int = 256


class Block(nn.Module):
    def __init__(self, cfg: ModelConfig):
        super().__init__()
        self.n_head = cfg.n_head
        self.head_dim = cfg.d // cfg.n_head
        self.scale = 1.0 / math.sqrt(self.head_dim)
        self.ln1 = nn.LayerNorm(cfg.d)
        self.qkv = nn.Linear(cfg.d, 3 * cfg.d)
        self.proj = nn.Linear(cfg.d, cfg.d)
        self.ln2 = nn.LayerNorm(cfg.d)
        self.mlp = nn.Sequential(nn.Linear(cfg.d, 4 * cfg.d), nn.GELU(), nn.Linear(4 * cfg.d, cfg.d))
        self.register_buffer("mask", torch.tril(torch.ones(cfg.ctx, cfg.ctx)).bool(), persistent=False)

    def forward(self, x):
        B, T, C = x.shape
        q, k, v = self.qkv(self.ln1(x)).split(C, dim=2)
        q, k, v = (t.reshape(B, T, self.n_head, self.head_dim).transpose(1, 2) for t in (q, k, v))
        # Attention is written out by hand (not F.scaled_dot_product_attention), with head
        # size and scale as constants, so that the Core ML conversion is predictable.
        att = (q @ k.transpose(-2, -1)) * self.scale
        att = att.masked_fill(~self.mask[:T, :T], float("-inf")).softmax(dim=-1)
        x = x + self.proj((att @ v).transpose(1, 2).reshape(B, T, C))
        return x + self.mlp(self.ln2(x))


class TinyGPT(nn.Module):
    def __init__(self, cfg: ModelConfig):
        super().__init__()
        self.cfg = cfg
        self.tok = nn.Embedding(cfg.vocab, cfg.d)
        self.pos = nn.Embedding(cfg.ctx, cfg.d)
        self.blocks = nn.ModuleList(Block(cfg) for _ in range(cfg.n_layer))
        self.ln = nn.LayerNorm(cfg.d)
        self.head = nn.Linear(cfg.d, cfg.vocab, bias=False)
        self.head.weight = self.tok.weight  # tied input/output embeddings
        self.apply(self._init)

    @staticmethod
    def _init(module):
        if isinstance(module, (nn.Linear, nn.Embedding)):
            nn.init.normal_(module.weight, mean=0.0, std=0.02)
        if isinstance(module, nn.Linear) and module.bias is not None:
            nn.init.zeros_(module.bias)

    def num_params(self):
        return sum(p.numel() for p in self.parameters()) - self.pos.weight.numel()

    def forward(self, idx):
        x = self.tok(idx) + self.pos.weight[: idx.shape[1]]
        for block in self.blocks:
            x = block(x)
        return self.head(self.ln(x))


def load_checkpoint(path, device="cpu"):
    ckpt = torch.load(path, map_location=device, weights_only=False)
    model = TinyGPT(ModelConfig(**ckpt["config"]))
    model.load_state_dict(ckpt["model"])
    return model.to(device).eval()


def boundary_ids(sp):
    """Token ids that can follow the end of a word.

    A candidate like কথা must also score the probability that the word *ends* there,
    otherwise it would get credit for being the prefix of কথাটা. A word ends when the
    next token starts a new word (▁...), is punctuation, or ends the sentence.
    """
    ids = [sp.eos_id()]
    for i in range(sp.get_piece_size()):
        if sp.is_control(i) or sp.is_unknown(i) or sp.is_byte(i):
            continue
        piece = sp.id_to_piece(i)
        if piece.startswith("▁") or not ("ঀ" <= piece[0] <= "৿"):
            ids.append(i)
    return sorted(set(ids))


@torch.no_grad()
def score_candidates(model, sp, context_words, candidates, boundary, device="cpu"):
    """log P(candidate, word end | context) for each candidate. Higher is better.

    This mirrors what the Swift side does with the Core ML export: one batch with a row
    per candidate, laid out as [eos] + context tokens + candidate tokens.
    """
    T = model.cfg.ctx
    ctx_ids = [i for w in context_words for i in sp.encode(w)]
    rows = []
    for cand in candidates:
        ids = sp.encode(cand)[: T - 1]
        room = T - 1 - len(ids)
        seq = [sp.eos_id()] + (ctx_ids[-room:] if room > 0 else []) + ids
        rows.append((seq, len(seq) - len(ids)))

    width = max(len(seq) for seq, _ in rows)
    x = torch.zeros(len(rows), width, dtype=torch.long)
    for n, (seq, _) in enumerate(rows):
        x[n, : len(seq)] = torch.tensor(seq)  # right padding never affects earlier positions
    logp = F.log_softmax(model(x.to(device)).float(), dim=-1).cpu()

    boundary = torch.as_tensor(boundary)
    scores = []
    for n, (seq, start) in enumerate(rows):
        s = sum(logp[n, t - 1, seq[t]].item() for t in range(start, len(seq)))
        s += torch.logsumexp(logp[n, len(seq) - 1, boundary], dim=0).item()
        scores.append(s)
    return scores
