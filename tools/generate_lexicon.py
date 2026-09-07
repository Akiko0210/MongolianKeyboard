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

2. Inflected forms and usage frequency — `bichig2cyrillic/lyrics.txt.gz`
   from tugstugi/mongolian-nlp: ~79k lines of modern Mongolian song lyrics in
   Cyrillic, converted to traditional script with Inner Mongolia University's
   converter (http://trans.mglip.com). Lines align word-for-word (suffixes are
   attached to their stem with U+202F), which yields ~50k Cyrillic→traditional
   word pairs including case-suffixed nouns and conjugated verbs, with counts.
   Pairs seen at least MIN_CORPUS_COUNT times, spelled the same way in at
   least MIN_SPELLING_SHARE of their occurrences, are merged into the lexicon
   (as new words, or as extra frequency for words the dictionary already has).

3. Frequency — `most_frequent_words.csv` from tugstugi/mongolian-nlp
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
CORPUS_URL = (
    "https://raw.githubusercontent.com/tugstugi/mongolian-nlp/"
    "master/bichig2cyrillic/lyrics.txt.gz"
)
MIN_CORPUS_COUNT = 2      # a spelling must occur at least this often
MIN_SPELLING_SHARE = 0.10 # ...and account for this share of the word's spellings
NNBSP = "\u202f"

# How the dictionary's authors romanize Cyrillic (sura0111/writtenMongolianKeyboard,
# src/database/updater/cyrillicToLatinMap.ts). Corpus words are keyed the same way
# so both sources answer the same typed text.
CYRILLIC_TO_LATIN = {
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "ye", "ё": "yo", "ж": "j",
    "з": "z", "и": "i", "й": "i", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o",
    "ө": "u", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ү": "u", "ф": "f",
    "х": "h", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sh", "ъ": "i", "ы": "ii", "ь": "i",
    "э": "e", "ю": "yu", "я": "ya",
}


def romanize(cyrillic: str) -> str:
    """Port of getLatinWord() from the dictionary's generator: a vowel that
    merely repeats the vowel of a preceding я/ю/е/ё is dropped (яа → ya)."""
    out = []
    prev = None
    for ch in cyrillic:
        cur = CYRILLIC_TO_LATIN.get(ch)
        if cur is None:
            return ""
        if prev and len(prev) == 2 and prev[0] == "y" and cur == prev[1]:
            cur = ""
        out.append(cur)
        prev = cur or prev
    return "".join(out)

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
    # y not followed by a vowel is й/ы/ь, which the dataset writes as i
    s = re.sub(r"y(?![aeiou])", "i", s)
    return s


def normalize_traditional(trad: str) -> str:
    """Bring the dataset's encoding to the standard Unicode sequences.

    The source writes every separated final a/e as <MVS, NIRUGU, a/e>
    (U+180E U+180A U+1820). Unicode (and Inner Mongolia University's own
    converter, see tools/verify_corpus.py) use <MVS, a/e>. With the extra
    nirugu, Noto Sans Mongolian shapes the preceding consonant as an ordinary
    final, draws a visible nirugu stroke and then a plain final a — i.e. the
    word renders wrongly (verified with HarfBuzz against the bundled font).
    """
    return trad.replace("\u180e\u180a", "\u180e")


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


def load_corpus_pairs(cache_dir: str):
    """(cyrillic, traditional) -> count, from the word-aligned lyrics corpus."""
    import gzip
    path = fetch(CORPUS_URL, os.path.join(cache_dir, "lyrics.txt.gz"))
    counts = {}
    allowed = ALLOWED_TRADITIONAL | {0x202F}
    with gzip.open(path, "rt", encoding="utf-8") as f:
        for line in f:
            if "|" not in line:
                continue
            cyr, trad = line.rstrip("\n").split("|", 1)
            cw = [w for w in cyr.split(" ") if w]      # NOT str.split(): U+202F is whitespace
            tw = [w for w in trad.split(" ") if w]
            if len(cw) != len(tw):
                continue
            for c, t in zip(cw, tw):
                if not CYRILLIC_RE.fullmatch(c) or "-" in c:
                    continue
                if not t or any(ord(ch) not in allowed for ch in t):
                    continue
                counts[(c, normalize_traditional(t))] = counts.get((c, normalize_traditional(t)), 0) + 1
    return counts


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
        trad = normalize_traditional(trad)
        key = fold_key(latin)
        freq = freqs.get(cyrillic, 0)
        slot = merged.get((key, trad))
        if slot is None or freq > slot[1]:
            merged[(key, trad)] = [cyrillic, freq]

    # ── Merge the corpus: inflected forms + usage counts ─────────────────────
    corpus = load_corpus_pairs(args.cache_dir)
    per_word = {}
    for (cyr, trad), n in corpus.items():
        per_word.setdefault(cyr, []).append((trad, n))
    added = boosted = 0
    from_corpus = set()
    for cyr, spellings in per_word.items():
        total = sum(n for _, n in spellings)
        latin = romanize(cyr)
        if not latin or not LATIN_RE.fullmatch(latin):
            continue
        for trad, n in spellings:
            if n < MIN_CORPUS_COUNT or n / total < MIN_SPELLING_SHARE:
                continue
            # ы is typed as `ii` by the dictionary's convention but often as a
            # single `i`; index the word under both.
            keys = {fold_key(latin)}
            if "ii" in latin:
                keys.add(fold_key(latin.replace("ii", "i")))
            # явъя is typed "yavya" at least as often as "yaviya": index both.
            stripped = re.sub(r"[ъь](?=[яёюе])", "", cyr)
            if stripped != cyr:
                alt = romanize(stripped)
                if alt and LATIN_RE.fullmatch(alt):
                    keys.add(fold_key(alt))
            for key in keys:
                slot = merged.get((key, trad))
                if slot is None:
                    merged[(key, trad)] = [cyr, max(n, freqs.get(cyr, 0))]
                    from_corpus.add((key, trad))
                    added += 1
                else:
                    if n > slot[1]:
                        slot[1] = n
                        boosted += 1
    print(f"  corpus: {len(corpus)} word pairs, {added} entries added, {boosted} frequencies raised")

    # Cyrillic typos in the lyrics (баина for байна, хаиртаи for хайртай)
    # converted letter by letter and now share a key with the real word.
    # A spelling that is both rare and a tiny fraction of its key's traffic
    # is such a typo, not a homophone: drop it.
    by_key = {}
    for (key, trad), (cyr, freq) in merged.items():
        by_key.setdefault(key, []).append((trad, cyr, freq))
    typos = 0
    for key, entries in by_key.items():
        top = max(f for _, _, f in entries)
        for trad, cyr, freq in entries:
            if (key, trad) not in from_corpus:
                continue    # dictionary words are never dropped
            if top >= 100 and freq < 20 and freq < 0.05 * top and cyr not in freqs:
                del merged[(key, trad)]
                typos += 1
    print(f"  dropped {typos} rare same-key spellings (corpus typos)")

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
