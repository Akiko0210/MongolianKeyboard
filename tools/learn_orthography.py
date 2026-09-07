#!/usr/bin/env python3
"""
Learn how typed Latin is spelled in traditional script, from the lexicon.

Traditional-script spelling is historical, not phonetic: a typed key such as
`amidral` is written ᠠᠮᠢᠳᠤᠷᠠᠯ (with a vowel Cyrillic dropped), `aav` is ᠠᠪᠤ,
`sain` is ᠰᠠᠶᠢᠨ. For words the dictionary has, the keyboard uses the verified
spelling. For words it lacks, it needs the best rule-based guess — and the
rules are learned here from the dictionary itself instead of being written
by hand.

Method
------
1. Alignment (hard EM): every lexicon pair <typed key, spelling> is aligned
   so that each key symbol emits 0–5 script characters (a symbol is a letter,
   or one of the digraphs ch/sh/ts). Emission probabilities start from a
   plausibility prior (a symbol should emit a letter it can stand for) and
   are re-estimated from the Viterbi alignments a few times.
   Suffixed noun forms (stem<NNBSP>suffix) are left out: SuffixEngine splits
   a known suffix off a typed word and attaches it by its own verified
   rules, so these rules only ever spell stems (and whole verb forms).
2. Rules: for each symbol in context — previous symbol, next symbol, the
   word's vowel-harmony class (masculine if it has a/o, feminine if e, else
   unknown, since u may be у/ө/ү), and the symbol after next — the most
   common emission is recorded. Contexts are pruned into a decision list:
   a context is kept only where its spelling differs from the more general
   context's, so the shipped table is small.
3. Evaluation: accuracy is measured on a held-out 10% of pairs BEFORE the
   final table is built from all pairs, and printed.

Output: Packages/MongolEngine/Sources/MongolEngine/Resources/orthography.tsv
    pattern <TAB> spelling
where pattern is the context fields joined with `|`, e.g. `a|^|v|m|$`.
The decoder in OrthographyConverter.swift MUST mirror decode() here.

Usage
-----
    python3 tools/learn_orthography.py            # after generate_lexicon.py
"""

import collections
import math
import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_lexicon import fold_key, romanize  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(ROOT, "Packages", "MongolEngine", "Sources", "MongolEngine", "Resources")
LEXICON_PATH = os.path.join(RESOURCES, "lexicon.tsv")
OUT_PATH = os.path.join(RESOURCES, "orthography.tsv")

ITERATIONS = 4
MAX_EMISSION = 5
MIN_SUPPORT = 2
NEG = -1e9
FORMAT_CHARS = set("᠊᠋᠌᠍᠎ ")

# Script letters a key symbol can stand for (a plausibility prior for the
# alignment, not a rule: emissions may contain other letters as well, e.g.
# the hidden ᠭ of a long vowel).
BASE = {
    "a": "ᠠ", "e": "ᠡ", "i": "ᠢᠶ", "o": "ᠣᠤ", "u": "ᠤᠦᠥᠣ", "y": "ᠶᠠᠡᠢ",
    "b": "ᠪ", "v": "ᠪᠸ", "g": "ᠭᠬ", "d": "ᠳᠲ", "j": "ᠵ", "z": "ᠵᠽ", "k": "ᠺᠭᠬ",
    "l": "ᠯ", "m": "ᠮ", "n": "ᠨᠩ", "p": "ᠫᠪ", "r": "ᠷ", "s": "ᠰᠱ", "t": "ᠲᠳ",
    "f": "ᠹ", "h": "ᠬᠭ", "C": "ᠴ", "S": "ᠰᠱ", "T": "ᠴᠼ",
}


def symbols(key: str) -> str:
    """ch/sh/ts become single symbols (same replacement order as Swift)."""
    return key.replace("ch", "C").replace("sh", "S").replace("ts", "T")


def harmony(syms: str) -> str:
    if "a" in syms or "o" in syms:
        return "m"
    if "e" in syms:
        return "f"
    return "u"


def contexts(syms: str, i: int):
    c = syms[i]
    p = syms[i - 1] if i > 0 else "^"
    n = syms[i + 1] if i + 1 < len(syms) else "$"
    nn = syms[i + 2] if i + 2 < len(syms) else "$"
    g = harmony(syms)
    return [
        (c, p, n, g, nn),
        (c, p, n, g),
        (c, p, n),
        (c, n, g),
        (c, p, g),
        (c, n),
        (c, p),
        (c, g),
        (c,),
    ]


# ── Stage 1: alignment ───────────────────────────────────────────────────────

_allowed_cache = {}


def allowed(c: str, s: str) -> bool:
    key = (c, s)
    r = _allowed_cache.get(key)
    if r is None:
        if s == "":
            r = True
        else:
            letters = [ch for ch in s if ch not in FORMAT_CHARS]
            r = bool(letters) and any(ch in BASE[c] for ch in letters)
        _allowed_cache[key] = r
    return r


def prior(c: str, s: str) -> float:
    if s == "":
        return -0.7 if c == "h" else -3.0     # h is silent after c/s (ch, sh)
    letters = [ch for ch in s if ch not in FORMAT_CHARS]
    p = -0.7 * abs(len(s) - 1)
    if letters[0] not in BASE[c]:
        p -= 1.5
    if s[0] in FORMAT_CHARS and s[0] not in " ᠎":
        p -= 1.0
    return p


class Aligner:
    def __init__(self):
        self.logp = collections.defaultdict(dict)
        self.default = collections.defaultdict(lambda: -8.0)

    def viterbi(self, syms: str, trad: str):
        n, m = len(syms), len(trad)
        best = [[NEG] * (m + 1) for _ in range(n + 1)]
        back = [[0] * (m + 1) for _ in range(n + 1)]
        best[0][0] = 0.0
        for i in range(1, n + 1):
            c = syms[i - 1]
            lp = self.logp[c]
            dlp = self.default[c]
            prev_row, row, brow = best[i - 1], best[i], back[i]
            for j in range(m + 1):
                b, arg = NEG, 0
                for length in range(min(MAX_EMISSION, j) + 1):
                    pj = prev_row[j - length]
                    if pj <= NEG / 2:
                        continue
                    s = trad[j - length:j]
                    p = lp.get(s)
                    if p is None:
                        if not allowed(c, s):
                            continue
                        p = prior(c, s) + dlp if not lp else dlp
                    v = pj + p
                    if v > b:
                        b, arg = v, length
                row[j], brow[j] = b, arg
        if best[n][m] <= NEG / 2:
            return None
        out, j = [], m
        for i in range(n, 0, -1):
            length = back[i][j]
            out.append(trad[j - length:j])
            j -= length
        return list(reversed(out))

    def train(self, pairs):
        for it in range(ITERATIONS):
            t0 = time.time()
            counts = collections.defaultdict(collections.Counter)
            unaligned = 0
            for syms, trad in pairs:
                al = self.viterbi(syms, trad)
                if al is None:
                    unaligned += 1
                    continue
                for c, s in zip(syms, al):
                    counts[c][s] += 1
            self.logp = collections.defaultdict(dict)
            for c, cnt in counts.items():
                total, distinct = sum(cnt.values()), len(cnt)
                for s, k in cnt.items():
                    self.logp[c][s] = math.log((k + 0.01) / (total + 0.01 * distinct))
                self.default[c] = math.log(0.001 / (total + 1))
            print(f"  alignment pass {it + 1}/{ITERATIONS}: {time.time() - t0:.0f}s, "
                  f"{unaligned} pairs could not be aligned", flush=True)

    def align(self, pairs):
        out = []
        for syms, trad in pairs:
            al = self.viterbi(syms, trad)
            if al is not None:
                out.append((syms, al))
        return out


# ── Stage 2: decision list ───────────────────────────────────────────────────

def build_rules(aligned):
    tables = collections.defaultdict(collections.Counter)
    order = []          # contexts in first-seen order per level
    seen = set()
    for syms, al in aligned:
        for i, s in enumerate(al):
            for ctx in contexts(syms, i):
                tables[ctx][s] += 1
                if ctx not in seen:
                    seen.add(ctx)
                    order.append(ctx)
    # general → specific: a context is kept only if it changes the spelling
    kept = {}

    def backoff_prediction(ctx):
        c = ctx[0]
        # every more general context of ctx, most specific first
        fields = {5: ("p", "n", "g", "nn"), 4: ("p", "n", "g"), 3: ("p", "n")}
        # reconstruct named fields from the tuple layout in contexts()
        named = {}
        if len(ctx) == 5:
            named = dict(zip(("p", "n", "g", "nn"), ctx[1:]))
        elif len(ctx) == 4:
            named = dict(zip(("p", "n", "g"), ctx[1:]))
        elif len(ctx) == 3:
            named = {"p": ctx[1], "n": ctx[2]} if ctx in three_pn else \
                    ({"n": ctx[1], "g": ctx[2]} if ctx in three_ng else {"p": ctx[1], "g": ctx[2]})
        elif len(ctx) == 2:
            named = {"n": ctx[1]} if ctx in two_n else \
                    ({"p": ctx[1]} if ctx in two_p else {"g": ctx[1]})
        chain = []
        p, n, g, nn = named.get("p"), named.get("n"), named.get("g"), named.get("nn")
        if len(ctx) > 4 and p and n and g: chain.append((c, p, n, g))
        if len(ctx) > 3 and p and n: chain.append((c, p, n))
        if len(ctx) > 3 and n and g: chain.append((c, n, g))
        if len(ctx) > 3 and p and g: chain.append((c, p, g))
        if len(ctx) > 2 and n: chain.append((c, n))
        if len(ctx) > 2 and p: chain.append((c, p))
        if len(ctx) > 2 and g: chain.append((c, g))
        if len(ctx) > 1: chain.append((c,))
        for k in chain:
            if k in kept:
                return kept[k]
        return ""

    # which 3-/2-tuples came from which level (tuples of equal length are
    # ambiguous otherwise)
    three_pn, three_ng, three_pg, two_n, two_p, two_g = set(), set(), set(), set(), set(), set()
    for syms, al in aligned:
        for i in range(len(al)):
            cs = contexts(syms, i)
            three_pn.add(cs[2]); three_ng.add(cs[3]); three_pg.add(cs[4])
            two_n.add(cs[5]); two_p.add(cs[6]); two_g.add(cs[7])
    for level_len in (1, 2, 3, 4, 5):
        for ctx in order:
            if len(ctx) != level_len:
                continue
            cnt = tables[ctx]
            if sum(cnt.values()) < MIN_SUPPORT:
                continue
            best = cnt.most_common(1)[0][0]
            if level_len == 1 or best != backoff_prediction(ctx):
                kept[ctx] = best
    return kept


def decode(rules, syms: str) -> str:
    out = []
    for i in range(len(syms)):
        for ctx in contexts(syms, i):
            if ctx in rules:
                out.append(rules[ctx])
                break
    return "".join(out)


def evaluate(rules, aligned_test):
    exact = sum(1 for syms, al in aligned_test if decode(rules, syms) == "".join(al))
    return exact / max(1, len(aligned_test))


def main():
    pairs = set()
    with open(LEXICON_PATH, encoding="utf-8") as f:
        for line in f:
            key, trad, cyr, _ = line.rstrip("\n").split("\t")
            # The lexicon indexes each word under every key people type for
            # it (amdral and amidral, yuu and yu). Learn from the canonical
            # key only: the variants would teach contradictory rules.
            if key != fold_key(romanize(cyr)):
                continue
            # Suffixed forms (stem<NNBSP>suffix) are handled by SuffixEngine,
            # which splits a known suffix off and spells only the stem with
            # these rules — so the rules are learned from stems (and verb
            # forms, which are single words) only.
            if "\u202f" in trad:
                continue
            syms = symbols(key)
            if all(ch in BASE for ch in syms):
                pairs.add((syms, trad))
    pairs = sorted(pairs)
    random.seed(7)
    random.shuffle(pairs)
    held_out = pairs[: len(pairs) // 10]
    training = pairs[len(pairs) // 10:]
    print(f"{len(pairs)} key→spelling pairs ({len(training)} train, {len(held_out)} held out)")

    print("Aligning (held-out evaluation)…")
    aligner = Aligner()
    aligner.train(training)
    rules = build_rules(aligner.align(training))
    test_pairs = aligner.align(held_out)
    acc = evaluate(rules, test_pairs)
    print(f"  held-out: {acc:.1%} of whole words spelled exactly by rule ({len(rules)} rules)")

    print("Aligning (all pairs, for the shipped table)…")
    aligner = Aligner()
    aligner.train(pairs)
    rules = build_rules(aligner.align(pairs))
    with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as f:
        for ctx, s in sorted(rules.items(), key=lambda kv: (len(kv[0]), kv[0])):
            f.write("|".join(ctx) + "\t" + s + "\n")
    print(f"Wrote {len(rules)} rules to {OUT_PATH}")
    for word in ["aav", "sain", "bagsh", "amidral", "nohoi", "hairtai", "batbayar", "ulaanbaatar"]:
        print(f"  {word:12s} → {decode(rules, symbols(word))}")


if __name__ == "__main__":
    main()
