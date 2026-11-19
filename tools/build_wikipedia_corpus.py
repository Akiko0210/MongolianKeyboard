#!/usr/bin/env python3
"""
Build word frequencies and next-word pairs from Mongolian Wikipedia.

Why: the frequency and bigram tables currently derive from
tugstugi/mongolian-nlp (Eduge news, lyrics). Neither repository carries any
licence at all — GitHub reports no LICENSE file and no SPDX licence for
either — so by default they are all rights reserved and cannot be
redistributed. That is the gate blocking submission in docs/RELEASE.md.

Mongolian Wikipedia is CC BY-SA, redistributable with attribution, and has
~11.1M running words across ~28.7k articles. That is smaller than Eduge's
23.7M but it is licensed, which the larger one is not.

Attribution is mandatory and is written into the header of every table this
produces: "Frequency and next-word data derived from Mongolian Wikipedia
(https://mn.wikipedia.org), CC BY-SA 4.0."

    python3 tools/build_wikipedia_corpus.py --out-dir .lexicon-cache
"""

import argparse
import bz2
import collections
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DUMP = os.path.join(ROOT, ".lexicon-cache", "mnwiki.xml.bz2")
ATTRIBUTION = ("# Derived from Mongolian Wikipedia (https://mn.wikipedia.org), "
               "CC BY-SA 4.0. Counts only; no article text is redistributed.")

WORD = re.compile(r"[а-яёөү]+")
# strip the markup that would otherwise be counted as words
STRIP = [
    (re.compile(r"<ref[^>]*>.*?</ref>", re.S), " "),
    (re.compile(r"\{\{.*?\}\}", re.S), " "),
    (re.compile(r"\[\[(?:[^\]|]*\|)?([^\]]*)\]\]"), r"\1"),
    (re.compile(r"<[^>]+>"), " "),
    (re.compile(r"https?://\S+"), " "),
    (re.compile(r"[=']{2,}"), " "),
]


def clean(text):
    for pattern, repl in STRIP:
        text = pattern.sub(repl, text)
    return text


def articles(path):
    """Stream (title, text) for main-namespace, non-redirect pages."""
    with bz2.open(path, "rb") as fh:
        for _, elem in ET.iterparse(fh, events=("end",)):
            tag = elem.tag.rsplit("}", 1)[-1]
            if tag != "page":
                continue
            ns = elem.findtext("./{*}ns")
            redirect = elem.find("./{*}redirect")
            text = elem.findtext("./{*}revision/{*}text")
            if ns == "0" and redirect is None and text:
                yield text
            elem.clear()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", default=DUMP)
    ap.add_argument("--out-dir", default=os.path.join(ROOT, ".lexicon-cache"))
    ap.add_argument("--min-pair", type=int, default=3,
                    help="drop next-word pairs seen fewer times than this")
    args = ap.parse_args()

    if not os.path.exists(args.dump):
        sys.exit(f"dump not found: {args.dump}")

    freq = collections.Counter()
    pairs = collections.Counter()
    pages = tokens = 0
    for text in articles(args.dump):
        words = WORD.findall(clean(text).lower())
        if not words:
            continue
        pages += 1
        tokens += len(words)
        freq.update(words)
        pairs.update(zip(words, words[1:]))
        if pages % 5000 == 0:
            sys.stderr.write(f"  {pages} pages, {tokens:,} words\n")

    os.makedirs(args.out_dir, exist_ok=True)
    fpath = os.path.join(args.out_dir, "wiki-frequency.tsv")
    with open(fpath, "w", encoding="utf-8") as fh:
        fh.write(ATTRIBUTION + "\n")
        for word, n in freq.most_common():
            fh.write(f"{word}\t{n}\n")

    bpath = os.path.join(args.out_dir, "wiki-bigrams.tsv")
    kept = 0
    with open(bpath, "w", encoding="utf-8") as fh:
        fh.write(ATTRIBUTION + "\n")
        for (a, b), n in pairs.most_common():
            if n < args.min_pair:
                break
            fh.write(f"{a}\t{b}\t{n}\n")
            kept += 1

    print(f"{pages:,} articles, {tokens:,} running words")
    print(f"  {len(freq):,} distinct words -> {fpath}")
    print(f"  {kept:,} next-word pairs (seen {args.min_pair}+ times) -> {bpath}")


if __name__ == "__main__":
    sys.exit(main())
