#!/usr/bin/env python3
"""
Compare two builds of the engine's resources (issue #20).

    python3 tools/compare_data_builds.py OLD_DIR NEW_DIR [--typed OLD.tsv NEW.tsv]

OLD_DIR and NEW_DIR each hold lexicon.tsv and bigrams.tsv. Evaluation text is
the Eduge news corpus and the lyrics corpus from tugstugi/mongolian-nlp. They
are used here only as evidence for measurement and are never shipped. The
legacy build was trained on both, so its numbers are an upper bound: the
comparison is "old on text it has seen" against "new on text it has not".

Measures
  coverage    share of running words whose Cyrillic form is in the lexicon,
              and how many of the 200 commonest words are missing
  predictions for each adjacent word pair inside a sentence: is there a
              prediction for the first word, and is the second word among
              the top 3
  typed       optional output of `mongolgen --type` for each build: share of
              words where Space commits traditional script rather than the
              unchanged input, and agreement with docs/authority.tsv
"""

import argparse
import collections
import gzip
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import generate_lexicon as g  # noqa: E402

CACHE = os.path.join(ROOT, ".lexicon-cache")


def lexicon_words(d):
    words = set()
    with open(os.path.join(d, "lexicon.tsv"), encoding="utf-8") as f:
        for line in f:
            cols = line.rstrip("\n").split("\t")
            if len(cols) == 4:
                words.add(cols[2])
    return words


def predictions(d):
    table = collections.defaultdict(list)
    with open(os.path.join(d, "bigrams.tsv"), encoding="utf-8") as f:
        for line in f:
            cols = line.rstrip("\n").split("\t")
            if len(cols) == 4:
                table[cols[0]].append(cols[2])
    return {k: v[:3] for k, v in table.items()}


def lyrics_counts():
    uni, bi = collections.Counter(), collections.Counter()
    with gzip.open(os.path.join(CACHE, "lyrics.txt.gz"), "rt", encoding="utf-8") as f:
        for line in f:
            cyr = line.split("|", 1)[0].lower()
            words = g.NEWS_WORD_RE.findall(cyr)
            uni.update(words)
            bi.update(zip(words, words[1:]))
    return uni, bi


def coverage(uni, words):
    total = sum(uni.values())
    hit = sum(n for w, n in uni.items() if w in words)
    top = [w for w, _ in uni.most_common(200)]
    missing = [w for w in top if w not in words]
    return hit / total, total, missing


def prediction_quality(bi, table):
    pairs = sum(bi.values())
    offered = sum(n for (a, _), n in bi.items() if a in table)
    hit = sum(n for (a, b), n in bi.items() if b in table.get(a, ()))
    return offered / pairs, hit / pairs, pairs


def load_authority():
    auth = {}
    with open(os.path.join(ROOT, "docs", "authority.tsv"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("#") or line.startswith("cyrillic\t"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) >= 2:
                auth[cols[0]] = g.normalize_traditional(cols[1])
    return auth


def typed(path, auth):
    n = script = agree = shared = 0
    for line in open(path, encoding="utf-8"):
        cols = line.rstrip("\n").split("\t")
        if len(cols) < 2:
            continue
        word, committed = cols[0], cols[1]
        n += 1
        if any(0x1820 <= ord(c) <= 0x18AF for c in committed):
            script += 1
        if word in auth:
            shared += 1
            agree += committed == auth[word]
    return n, script, shared, agree


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("old")
    ap.add_argument("new")
    ap.add_argument("--typed", nargs=2, metavar=("OLD", "NEW"))
    args = ap.parse_args()

    news_uni, news_bi = g.load_news_stats(CACHE)
    news_uni = collections.Counter(news_uni)
    news_bi = collections.Counter(news_bi)
    lyr_uni, lyr_bi = lyrics_counts()

    for label, d in (("old", args.old), ("new", args.new)):
        words = lexicon_words(d)
        table = predictions(d)
        print(f"== {label}: {d}")
        print(f"  lexicon: {len(words)} Cyrillic words; predictions for {len(table)} head words")
        for name, uni in (("news", news_uni), ("lyrics", lyr_uni)):
            share, total, missing = coverage(uni, words)
            print(f"  coverage {name}: {share:.1%} of {total:,} running words; "
                  f"top-200 missing {len(missing)}: {' '.join(missing[:12])}")
        for name, bi in (("news", news_bi), ("lyrics", lyr_bi)):
            offered, hit, pairs = prediction_quality(bi, table)
            print(f"  predictions {name}: offered {offered:.1%}, next word in top 3 "
                  f"{hit:.1%} of {pairs:,} word pairs")
        for head in ("сайн", "байна", "би", "энэ", "монгол"):
            print(f"    after {head}: {', '.join(table.get(head, [])) or '-'}")

    if args.typed:
        auth = load_authority()
        for label, path in zip(("old", "new"), args.typed):
            n, script, shared, agree = typed(path, auth)
            print(f"== typed {label}: Space commits script for {script}/{n} "
                  f"({script / n:.1%}); agrees with authority on {agree}/{shared} "
                  f"({agree / max(shared, 1):.1%})")


if __name__ == "__main__":
    main()
