#!/usr/bin/env python3
"""
Cross-check generated traditional-script spellings against evidence.

This tool reports what the evidence says, and nothing more. Three verdicts:

    attested     evidence contains this key and spells it the same way
    contradicted evidence contains this key and spells it differently  <- a real defect
    unattested   no evidence either way                                <- NOT a defect

The distinction matters: 32% of the shipped lexicon is unattested in the
corpus and nearly all of it is legitimate rare vocabulary. Treating
"unattested" as "wrong" would delete real Mongolian.

Evidence sources, in precedence order:

 1. --authority FILE   a reviewed dictionary (TSV: cyrillic <TAB> traditional).
                       This is the only source that can settle correctness.
                       None is bundled; supply one.
 2. the lyrics corpus  ~79k lines machine-converted by trans.mglip.com. It is
                       *not* literature and it is not authoritative: it is the
                       same data orthography.tsv was learned from.

Because of (2), a plain run is circular — the rules are being checked against
their own training data. --holdout breaks that: the corpus is split by a hash
of the key, rules see only the train half, and scoring happens on the unseen
test half. Only a --holdout number means anything about generalization.

    swift run mongolgen --spell < keys.txt | python3 tools/crosscheck_words.py --holdout
    ... | python3 tools/crosscheck_words.py --authority docs/reviewed.tsv
"""

import argparse
import gzip
import hashlib
import os
import sys
import urllib.request
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CACHE = os.path.join(ROOT, ".lexicon-cache")
CORPUS_URL = ("https://raw.githubusercontent.com/tugstugi/mongolian-nlp/"
              "master/bichig2cyrillic/lyrics.txt.gz")
NNBSP, MVS = " ", "᠎"
MASC, FEM = {0x1820, 0x1823, 0x1824}, {0x1821, 0x1825, 0x1826}


def harmony_violation(word):
    """A native word keeps to one vowel class (Poppe, Grammar of Written
    Mongolian, §§32-34). Checked per word: harmony stops at a word boundary."""
    for part in word.replace(NNBSP, " ").replace(MVS, " ").split(" "):
        if not part:
            continue
        if any(ord(c) in MASC for c in part) and any(ord(c) in FEM for c in part):
            return True
    return False


def fetch(url, path):
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        sys.stderr.write(f"downloading {url}\n")
        urllib.request.urlretrieve(url, path)
    return path


def in_test_half(key):
    """Deterministic 80/20 split, stable across runs and machines."""
    return hashlib.sha1(key.encode("utf-8")).digest()[0] < 51  # 51/256 ~ 20%


def load_corpus(holdout):
    """Cyrillic word -> set of traditional spellings seen for it."""
    path = fetch(CORPUS_URL, os.path.join(CACHE, "lyrics.txt.gz"))
    pairs = {}
    with gzip.open(path, "rt", encoding="utf-8") as fh:
        for line in fh:
            if "|" not in line:
                continue
            cyr, trad = line.rstrip("\n").split("|", 1)
            cyr_words = [w for w in cyr.split(" ") if w]
            trad_words = [w for w in trad.split(" ") if w]
            if len(cyr_words) != len(trad_words):
                continue  # unaligned line: not a usable data point
            for c, t in zip(cyr_words, trad_words):
                c = c.strip().lower()
                if not c or not t.strip():
                    continue
                if holdout and not in_test_half(c):
                    continue  # train half: the rules may have seen it
                pairs.setdefault(c, set()).add(t.strip())
    return pairs


def load_authority(path):
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            cols = line.rstrip("\n").split("\t")
            if line.startswith("#"): continue
            if len(cols) >= 2 and cols[0] and cols[1]:
                out.setdefault(cols[0].strip().lower(), set()).add(cols[1].strip())
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--holdout", action="store_true",
                    help="score only against corpus entries the rules did not see")
    ap.add_argument("--authority", help="reviewed dictionary TSV (cyrillic<TAB>traditional)")
    ap.add_argument("--show", type=int, default=12, help="contradictions to print")
    args = ap.parse_args()

    authority = load_authority(args.authority) if args.authority else {}
    corpus = load_corpus(args.holdout)
    if args.authority:
        sys.stderr.write(f"authority: {len(authority)} reviewed entries\n")
    sys.stderr.write(f"corpus: {len(corpus)} distinct words"
                     f"{' (held-out 20%)' if args.holdout else ' (ALL — circular)'}\n")

    verdicts, contradictions, violations = Counter(), [], []
    for line in sys.stdin:
        cols = line.rstrip("\n").split("\t")
        if len(cols) < 2:
            continue
        key, form = cols[0].strip().lower(), cols[1].strip()
        if not form:
            verdicts["no-rule"] += 1
            continue
        if harmony_violation(form):
            violations.append((key, form))
        source, seen = ("authority", authority.get(key)) if key in authority \
            else ("corpus", corpus.get(key))
        if not seen:
            verdicts["unattested"] += 1
        elif form in seen:
            verdicts[f"attested ({source})"] += 1
        else:
            verdicts[f"contradicted ({source})"] += 1
            contradictions.append((key, form, sorted(seen)[0], source))

    total = sum(verdicts.values())
    print(f"\n{'verdict':<28} {'count':>8}  share")
    print("-" * 48)
    for k, n in verdicts.most_common():
        print(f"{k:<28} {n:>8}  {n/total:6.1%}" if total else k)
    judged = sum(n for k, n in verdicts.items() if "attested (" in k or "contradicted" in k)
    if judged:
        ok = sum(n for k, n in verdicts.items() if k.startswith("attested"))
        print(f"\naccuracy where evidence exists: {ok}/{judged} = {ok/judged:.1%}")
        print("(words with no evidence are excluded, not counted as failures)")
    else:
        print("\nNo evidence covered any generated form — no accuracy can be stated.")

    print(f"\nvowel-harmony violations in generated output: {len(violations)}"
          f" ({len(violations)/total:.1%})" if total else "")
    for key, form in violations[:args.show]:
        print(f"    {key:<20} -> {form}")

    if contradictions:
        print(f"\ncontradicted by evidence — these are rule defects:")
        print(f"    {'key':<18} {'generated':<22} {'evidence says':<22} source")
        for key, got, want, src in contradictions[:args.show]:
            print(f"    {key:<18} {got:<22} {want:<22} {src}")
    return 1 if contradictions else 0


if __name__ == "__main__":
    sys.exit(main())
