#!/usr/bin/env python3
"""
Generate Packages/MongolEngine/Sources/MongolEngine/Resources/lexicon.tsv
from open datasets.

Sources
-------
1. Word dictionary — the `written-mongol-keyboard` npm package (MIT), which
   bundles ~28k entries of {cyrillic, latin, traditional}: a Cyrillic Mongolian
   word, its pronunciation romanization (how Mongolians actually type on a
   QWERTY keyboard), and the correct traditional-script (mongol bichig)
   spelling. https://www.npmjs.com/package/written-mongol-keyboard
   (repo: https://github.com/sura0111/writtenMongolianKeyboard)

2. Frequency — `most_frequent_words.csv` from tugstugi/mongolian-nlp
   (250 most frequent Mongolian words over a 670M-word news/books/Wikipedia
   corpus). Used to rank candidates so common words come first.
   https://github.com/tugstugi/mongolian-nlp

Cleaning
--------
The dictionary contains a few hundred defective rows where the converter that
produced it failed (traditional column contains Latin/Cyrillic/CJK text or
U+FFFD instead of Mongolian script). Those are dropped: this keyboard's goal
is accuracy, so a missing word (which falls back to letter-by-letter
transliteration) is better than a wrong suggestion.

Output format
-------------
TSV, sorted by column 1, one candidate per line:

    key <TAB> traditional <TAB> cyrillic <TAB> frequency

`key` is the *folded* lookup key (see fold_key below — the same folding is
implemented in Swift in LatinKey.swift and MUST stay in sync).
`frequency` is an integer (scaled corpus frequency, 0 if unknown).

Usage
-----
    python3 tools/generate_lexicon.py [--cache-dir DIR]

Downloads go to --cache-dir (default: .lexicon-cache/, git-ignored) and are
reused on re-runs.
"""

import argparse
import csv
import io
import json
import os
import re
import sys
import tarfile
import urllib.request

DICT_PACKAGE_URL = (
    "https://registry.npmjs.org/written-mongol-keyboard/-/"
    "written-mongol-keyboard-1.3.5.tgz"
)
FREQ_URL = (
    "https://raw.githubusercontent.com/tugstugi/mongolian-nlp/"
    "master/datasets/most_frequent_words.csv"
)

OUT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Packages", "MongolEngine", "Sources", "MongolEngine",
    "Resources", "lexicon.tsv",
)

# Scalars a valid traditional-script word may contain: the Mongolian letters
# plus the format characters that are part of correct orthography
# (nirugu, FVS1-3, MVS, NNBSP).
ALLOWED_TRADITIONAL = (
    set(range(0x1820, 0x1843))
    | {0x180A, 0x180B, 0x180C, 0x180D, 0x180E, 0x202F}
)

CYRILLIC_RE = re.compile(r"^[а-яёөү-]+$")
LATIN_RE = re.compile(r"^[a-z]+$")


def fold_key(latin: str) -> str:
    """Normalize a romanization to its lookup key.

    Folds the spelling variants Mongolians use interchangeably on QWERTY into
    one canonical form. Verified against the dataset: none of these folds
    collide with a genuine letter sequence (e.g. `kh`, `q`, `w`, `x` and
    standalone `c` never occur in the dictionary's romanizations). `gh` is
    deliberately NOT folded: in this dataset it is always a real g+h sequence
    (budeghen = будэгхэн), never a digraph for г.

    Keep in sync with LatinKey.fold in
    Packages/MongolEngine/Sources/MongolEngine/LatinKey.swift.
    """
    s = latin.lower()
    s = s.replace("ö", "u").replace("ü", "u")
    s = s.replace("oe", "u").replace("ue", "u")
    s = s.replace("kh", "h")
    s = s.replace("q", "h").replace("x", "h")
    s = s.replace("w", "v")
    # standalone c → ts, but keep the ch digraph
    s = re.sub(r"c(?!h)", "ts", s)
    return s


def fetch(url: str, dest: str) -> str:
    if os.path.exists(dest):
        print(f"  cached: {dest}")
        return dest
    print(f"  downloading {url}")
    urllib.request.urlretrieve(url, dest)
    return dest


def load_dictionary(cache_dir: str):
    """Extract the embedded JSON dictionary from the npm package bundle."""
    tgz = fetch(DICT_PACKAGE_URL, os.path.join(cache_dir, "written-mongol-keyboard-1.3.5.tgz"))
    with tarfile.open(tgz) as tar:
        bundle = tar.extractfile("package/dist/index.js").read().decode("utf-8")

    marker = "JSON.parse('"
    i = bundle.find(marker)
    if i < 0:
        sys.exit("error: dictionary JSON not found in package bundle")
    start = i + len(marker)
    j = start
    while True:  # find the closing unescaped single quote
        j = bundle.find("'", j)
        k = j - 1
        backslashes = 0
        while bundle[k] == "\\":
            backslashes += 1
            k -= 1
        if backslashes % 2 == 0:
            break
        j += 1
    return json.loads(bundle[start:j].replace("\\'", "'"))


def load_frequencies(cache_dir: str):
    path = fetch(FREQ_URL, os.path.join(cache_dir, "most_frequent_words.csv"))
    freqs = {}
    with open(path, encoding="utf-8") as f:
        reader = csv.reader(f, skipinitialspace=True)
        next(reader)  # header
        for word, freq in reader:
            freqs[word.strip()] = int(round(float(freq) * 1_000_000))
    return freqs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", default=os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        ".lexicon-cache"))
    args = parser.parse_args()
    os.makedirs(args.cache_dir, exist_ok=True)

    print("Loading sources…")
    entries = load_dictionary(args.cache_dir)
    freqs = load_frequencies(args.cache_dir)
    print(f"  {len(entries)} raw dictionary entries, {len(freqs)} frequency rows")

    dropped_junk = dropped_shape = 0
    # (key, traditional) -> [cyrillic, freq]
    merged = {}
    for e in entries:
        latin, cyrillic, trad = e["latin"], e["cyrillic"], e["traditional"]
        if not (LATIN_RE.fullmatch(latin) and CYRILLIC_RE.fullmatch(cyrillic)):
            dropped_shape += 1
            continue
        if not trad or any(ord(ch) not in ALLOWED_TRADITIONAL for ch in trad):
            dropped_junk += 1
            continue
        key = fold_key(latin)
        freq = freqs.get(cyrillic, 0)
        slot = merged.get((key, trad))
        if slot is None or freq > slot[1]:
            merged[(key, trad)] = [cyrillic, freq]

    rows = sorted(
        (key, trad, cyr, freq)
        for (key, trad), (cyr, freq) in merged.items()
    )
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as f:
        for key, trad, cyr, freq in rows:
            f.write(f"{key}\t{trad}\t{cyr}\t{freq}\n")

    ranked = sum(1 for r in rows if r[3] > 0)
    print(f"Wrote {len(rows)} entries to {OUT_PATH}")
    print(f"  dropped: {dropped_junk} defective traditional, {dropped_shape} malformed latin/cyrillic")
    print(f"  {ranked} entries carry corpus frequency")


if __name__ == "__main__":
    main()
