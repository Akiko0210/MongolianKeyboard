#!/usr/bin/env python3
"""
Verify the suffix and conjugation rules in SuffixEngine.swift / VerbEngine.swift
against real text.

Source: bichig2cyrillic/lyrics.txt.gz from tugstugi/mongolian-nlp — ~79k lines
of modern Mongolian in Cyrillic, each converted to traditional script by Inner
Mongolia University's converter (http://trans.mglip.com). Lines align word for
word (a suffix is joined to its stem with U+202F, never a space), so every
(cyrillic word, traditional word) pair is a data point.

For each Cyrillic ending the script prints which written suffix the corpus
uses, split by the last letter of the written stem (V = vowel), with counts.
For verbs it first locates the infinitive in the lexicon so the stem is known.
Read the tables next to the rules in the Swift files: each rule cites them.

    python3 tools/verify_corpus.py            # uses .lexicon-cache/, downloads once
"""

import collections
import gzip
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(os.path.dirname(HERE), ".lexicon-cache")
CORPUS_URL = ("https://raw.githubusercontent.com/tugstugi/mongolian-nlp/"
              "master/bichig2cyrillic/lyrics.txt.gz")
LEXICON = os.path.join(os.path.dirname(HERE), "Packages", "MongolEngine", "Sources",
                       "MongolEngine", "Resources", "lexicon.tsv")
NNBSP = " "
MVS = "᠎"
VOWELS = {chr(c) for c in range(0x1820, 0x1828)}
CYR = re.compile(r"^[а-яёөү]+$")


def final_letter(s):
    for ch in reversed(s):
        if 0x1820 <= ord(ch) <= 0x1842:
            return ch


def stem_class(s):
    f = final_letter(s)
    return "?" if f is None else ("V" if f in VOWELS else f)


def strip_fvs(s):
    return "".join(ch for ch in s if not 0x180B <= ord(ch) <= 0x180D)


def load_pairs():
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, "lyrics.txt.gz")
    if not os.path.exists(path):
        print("downloading corpus…", file=sys.stderr)
        urllib.request.urlretrieve(CORPUS_URL, path)
    pairs = collections.Counter()
    with gzip.open(path, "rt", encoding="utf-8") as f:
        for line in f:
            if "|" not in line:
                continue
            cy, tr = line.rstrip("\n").split("|", 1)
            cw = [w for w in cy.split(" ") if w]
            tw = [w for w in tr.split(" ") if w]
            if len(cw) != len(tw):
                continue
            for c, t in zip(cw, tw):
                if CYR.match(c) and all(0x1800 <= ord(ch) <= 0x18AF or ch == NNBSP for ch in t):
                    pairs[(c, t)] += 1
    return pairs


NOUN_ENDINGS = [
    "гийн", "ийн", "ын", "ний", "ны", "гийг", "ийг", "ыг", "анд", "энд", "онд", "өнд", "д", "т",
    "наас", "нээс", "аас", "ээс", "оос", "өөс", "аар", "ээр", "оор", "өөр", "тай", "тэй", "той",
    "гаа", "гээ", "аа", "ээ", "оо", "өө", "даа", "дээ", "таа", "тээ", "нууд", "нүүд", "ууд", "үүд",
    "чууд", "гүй",
]

VERB_ENDINGS = {
    "past -сан": ["сан", "сэн", "сон", "сөн"], "non-past -на": ["на", "нэ", "но", "нө"],
    "converb -ж/-ч": ["ж", "ч"], "habitual -даг": ["даг", "дэг", "дог", "дөг"],
    "perfective -аад": ["аад", "ээд", "оод", "өөд"], "recent past -лаа": ["лаа", "лээ", "лоо", "лөө"],
    "evidential -жээ": ["жээ", "чээ"], "simple past -в": ["ав", "эв", "ов", "өв", "в"],
    "voluntative -ъя": ["ъя", "ье", "ъё"], "desiderative -маар": ["маар", "мээр", "моор", "мөөр"],
    "progressive -гаа": ["гаа", "гээ", "гоо", "гөө"], "imperative -аарай": ["аарай", "ээрэй", "оорой", "өөрэй"],
    "negative -хгүй": ["хгүй"],
}
INFINITIVE_ENDINGS = ["х", "ах", "эх", "ох", "өх", "их"]


def main():
    pairs = load_pairs()
    print(f"{sum(pairs.values())} word tokens, {len(pairs)} distinct pairs\n")

    print("=== NOUN SUFFIXES: written form by (Cyrillic ending, written stem-final) ===")
    table = collections.defaultdict(collections.Counter)
    for (c, t), n in pairs.items():
        if t.count(NNBSP) != 1:
            continue
        stem, sfx = t.split(NNBSP)
        for e in sorted(NOUN_ENDINGS, key=len, reverse=True):
            if c.endswith(e) and len(c) > len(e) + 1:
                table[(e, stem_class(stem))][sfx] += n
                break
    for e in NOUN_ENDINGS:
        for (ee, cls), cnt in sorted(table.items()):
            if ee != e or sum(cnt.values()) < 5:
                continue
            tot = sum(cnt.values())
            print(f"  -{e:5s} after {cls}: " + ", ".join(f"{s} {v/tot:.0%} ({v})" for s, v in cnt.most_common(3)))

    print("\n=== STACKED SUFFIXES (two U+202F) ===")
    chains = collections.defaultdict(collections.Counter)
    for (c, t), n in pairs.items():
        if t.count(NNBSP) != 2:
            continue
        parts = t.split(NNBSP)
        for e in ["ынхаа", "ийнхээ", "ныхаа", "нийхээ", "тайгаа", "тэйгээ", "аасаа", "ээсээ", "аараа", "ээрээ", "даа", "дээ", "таа", "тээ"]:
            if c.endswith(e) and len(c) > len(e) + 1:
                chains[e][parts[1] + " + " + parts[2]] += n
                break
    for e, cnt in chains.items():
        tot = sum(cnt.values())
        print(f"  -{e:7s} " + ", ".join(f"{a} {v/tot:.0%} ({v})" for a, v in cnt.most_common(2)))

    print("\n=== VERB SUFFIXES: attached form by (suffix, written stem-final) ===")
    lexicon = collections.defaultdict(set)
    for line in open(LEXICON, encoding="utf-8"):
        _, trad, cyr, _ = line.rstrip("\n").split("\t")
        if cyr.endswith("х") and (trad.endswith("ᠬᠤ") or trad.endswith("ᠬᠦ")):
            lexicon[cyr].add(trad)
    vt = collections.defaultdict(collections.Counter)
    for (c, t), n in pairs.items():
        if n < 2:
            continue
        for name, ends in VERB_ENDINGS.items():
            hit = next((e for e in ends if c.endswith(e) and len(c) > len(e) + 1), None)
            if not hit:
                continue
            base = c[:-len(hit)]
            for lemma in (base + i for i in INFINITIVE_ENDINGS if base + i in lexicon):
                for inf in lexicon[lemma]:
                    stem = strip_fvs(inf[:-2])
                    tt = strip_fvs(t)
                    if tt.startswith(stem) and len(tt) > len(stem):
                        vt[(name, stem_class(stem))][tt[len(stem):].replace(NNBSP, " ")] += n
    for name in VERB_ENDINGS:
        for (nm, cls), cnt in sorted(vt.items()):
            if nm != name or sum(cnt.values()) < 5:
                continue
            tot = sum(cnt.values())
            print(f"  {name:20s} after {cls}: " + ", ".join(f"{s} {v/tot:.0%} ({v})" for s, v in cnt.most_common(3)))


if __name__ == "__main__":
    main()
