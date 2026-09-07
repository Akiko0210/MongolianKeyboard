#!/usr/bin/env python3
"""
Generate the engine's data files from open datasets:

  Packages/MongolEngine/Sources/MongolEngine/Resources/lexicon.tsv
  Packages/MongolEngine/Sources/MongolEngine/Resources/bigrams.tsv

Sources
-------
1. Word dictionary — the `written-mongol-keyboard` npm package (MIT), which
   bundles ~28k entries of {cyrillic, latin, traditional}: a Cyrillic Mongolian
   word, its pronunciation romanization (how Mongolians actually type on a
   QWERTY keyboard), and the correct traditional-script (mongol bichig)
   spelling. https://www.npmjs.com/package/written-mongol-keyboard
   (repo: https://github.com/sura0111/writtenMongolianKeyboard)

2. Inflected forms — `bichig2cyrillic/lyrics.txt.gz` from
   tugstugi/mongolian-nlp: ~79k lines of modern Mongolian song lyrics in
   Cyrillic, converted to traditional script with Inner Mongolia University's
   converter (http://trans.mglip.com). Lines align word-for-word (suffixes are
   attached to their stem with U+202F), which yields ~50k Cyrillic→traditional
   word pairs including case-suffixed nouns and conjugated verbs, with counts.
   Pairs seen at least MIN_CORPUS_COUNT times, spelled the same way in at
   least MIN_SPELLING_SHARE of their occurrences, are merged into the lexicon.

3. How people actually write — `datasets/eduge.csv.gz` from
   tugstugi/mongolian-nlp: 75k Mongolian news articles (Eduge.mn), 23.7M
   running words. Every Cyrillic form's count becomes its `frequency`
   (added to its lyrics count, so colloquial words are represented too), which
   ranks homophones and completions. Word-pair counts from both corpora
   become the next-word table (bigrams.tsv).

Cleaning
--------
The dictionary contains a few hundred defective rows where the converter that
produced it failed (traditional column contains Latin/Cyrillic/CJK text or
U+FFFD instead of Mongolian script). Those are dropped: this keyboard's goal
is accuracy, so a missing word (which falls back to rule-based spelling) is
better than a wrong suggestion.

Typing variants
---------------
Mongolians have no single Latin spelling convention. Every word is indexed
under every key people plausibly type for it (see typed_keys): the
dictionary's own romanization (ө/ү→u, х→h, й→i, ы→ii, ь→i, е→ye, ю→yu …),
ы/ий as a single `i`, ь/ъ dropped (амьдрал → amdral), long iotated vowels
kept double (юу → yuu, яа → yaa), and е as plain `e` (ерөнхий → erunhii).
Spellings with x/kh/q/w/c/ö/ü/y-before-consonant are folded onto these keys
at lookup time by LatinKey.fold (Swift) / fold_key (here) — those two MUST
stay in sync.

Output format
-------------
lexicon.tsv — sorted by column 1, one candidate per line:

    key <TAB> traditional <TAB> cyrillic <TAB> frequency

bigrams.tsv — sorted by column 1, up to TOP_SUCCESSORS lines per head word:

    previous cyrillic <TAB> next traditional <TAB> next cyrillic <TAB> count

Usage
-----
    python3 tools/generate_lexicon.py [--cache-dir DIR]

Downloads go to --cache-dir (default: .lexicon-cache/, git-ignored) and are
reused on re-runs. The news corpus is 74 MB; its word counts are cached as
news_stats.json after the first run.
"""

import argparse
import collections
import csv
import gzip
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
CORPUS_URL = (
    "https://raw.githubusercontent.com/tugstugi/mongolian-nlp/"
    "master/bichig2cyrillic/lyrics.txt.gz"
)
NEWS_URL = (
    "https://raw.githubusercontent.com/tugstugi/mongolian-nlp/"
    "master/datasets/eduge.csv.gz"
)
MIN_CORPUS_COUNT = 2      # a spelling must occur at least this often
MIN_SPELLING_SHARE = 0.10 # ...and account for this share of the word's spellings
MIN_BIGRAM = 5            # a next-word pair must occur at least this often
MIN_HEAD_FREQ = 50        # ...after a word at least this frequent
TOP_SUCCESSORS = 3        # next-word predictions kept per head word
NNBSP = " "

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

OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Packages", "MongolEngine", "Sources", "MongolEngine", "Resources",
)
LEXICON_PATH = os.path.join(OUT_DIR, "lexicon.tsv")
BIGRAMS_PATH = os.path.join(OUT_DIR, "bigrams.tsv")

# Scalars a valid traditional-script word may contain: the Mongolian letters
# plus the format characters that are part of correct orthography
# (nirugu, FVS1-3, MVS, NNBSP).
ALLOWED_TRADITIONAL = (
    set(range(0x1820, 0x1843))
    | {0x180A, 0x180B, 0x180C, 0x180D, 0x180E, 0x202F}
)

CYRILLIC_RE = re.compile(r"^[а-яёөү-]+$")
LATIN_RE = re.compile(r"^[a-z]+$")
SOFT_SIGN_RE = re.compile(r"[ъь]")
NEWS_WORD_RE = re.compile(r"[а-яёөүА-ЯЁӨҮ]+")
SENTENCE_SPLIT_RE = re.compile(r"[.!?…;:()\"«»“”\n]+")


def romanize(cyrillic: str, dedupe: bool = True, ye: str = "ye") -> str:
    """Port of getLatinWord() from the dictionary's generator. With `dedupe`
    a vowel that merely repeats the vowel of a preceding я/ю/е/ё is dropped
    (яа → ya); without it the vowel is kept (яа → yaa), which is how most
    people type. `ye` is the spelling used for е."""
    out = []
    prev = None
    for ch in cyrillic:
        cur = ye if ch == "е" else CYRILLIC_TO_LATIN.get(ch)
        if cur is None:
            return ""
        if dedupe and prev and len(prev) == 2 and prev[0] == "y" and cur == prev[1]:
            cur = ""
        out.append(cur)
        prev = cur or prev
    return "".join(out)


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


def typed_keys(cyrillic: str) -> set:
    """Every folded key people plausibly type for a Cyrillic word."""
    keys = set()
    for cyr in {cyrillic, SOFT_SIGN_RE.sub("", cyrillic)}:
        for dedupe in (True, False):
            for ye in ("ye", "e"):
                latin = romanize(cyr, dedupe, ye)
                if not latin or not LATIN_RE.fullmatch(latin):
                    continue
                key = fold_key(latin)
                keys.add(key)
                # ы and ий are typed as `ii` by the dictionary's convention
                # but at least as often as a single `i`.
                if "ii" in key:
                    keys.add(key.replace("ii", "i"))
    return keys


def normalize_traditional(trad: str) -> str:
    """Bring the dataset's encoding to the standard Unicode sequences.

    The source writes every separated final a/e as <MVS, NIRUGU, a/e>
    (U+180E U+180A U+1820). Unicode (and Inner Mongolia University's own
    converter, see tools/verify_corpus.py) use <MVS, a/e>. With the extra
    nirugu, Noto Sans Mongolian shapes the preceding consonant as an ordinary
    final, draws a visible nirugu stroke and then a plain final a — i.e. the
    word renders wrongly (verified with HarfBuzz against the bundled font).
    """
    return trad.replace("᠎᠊", "᠎")


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


def load_corpus(cache_dir: str):
    """From the word-aligned lyrics corpus:
    (cyrillic, traditional) -> count, and (cyrillic, next cyrillic) -> count."""
    path = fetch(CORPUS_URL, os.path.join(cache_dir, "lyrics.txt.gz"))
    pairs = collections.Counter()
    bigrams = collections.Counter()
    with gzip.open(path, "rt", encoding="utf-8") as f:
        for line in f:
            if "|" not in line:
                continue
            cyr, trad = line.rstrip("\n").split("|", 1)
            cw = [w for w in cyr.split(" ") if w]      # NOT str.split(): U+202F is whitespace
            tw = [w for w in trad.split(" ") if w]
            bigrams.update(zip(cw, cw[1:]))
            if len(cw) != len(tw):
                continue
            for c, t in zip(cw, tw):
                if not CYRILLIC_RE.fullmatch(c) or "-" in c:
                    continue
                if not t or any(ord(ch) not in ALLOWED_TRADITIONAL for ch in t):
                    continue
                pairs[(c, normalize_traditional(t))] += 1
    return pairs, bigrams


def load_news_stats(cache_dir: str):
    """Word and word-pair counts over the Eduge news corpus (cached as JSON)."""
    stats_path = os.path.join(cache_dir, "news_stats.json")
    if os.path.exists(stats_path):
        print(f"  cached: {stats_path}")
        with open(stats_path, encoding="utf-8") as f:
            data = json.load(f)
        return data["uni"], {tuple(k.split(" ")): v for k, v in data["bi"].items()}

    path = fetch(NEWS_URL, os.path.join(cache_dir, "eduge.csv.gz"))
    print("  counting words in the news corpus (takes a few minutes)…")
    csv.field_size_limit(1 << 30)
    uni = collections.Counter()
    bi = collections.Counter()
    docs = 0
    with gzip.open(path, "rt", encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        next(reader)  # header: news, label
        for row in reader:
            if not row:
                continue
            docs += 1
            for sentence in SENTENCE_SPLIT_RE.split(row[0]):
                words = [w.lower() for w in NEWS_WORD_RE.findall(sentence)]
                uni.update(words)
                bi.update(zip(words, words[1:]))
    print(f"  {docs} articles, {sum(uni.values())} words, {len(uni)} distinct")
    bi = {k: v for k, v in bi.items() if v >= 3}
    with open(stats_path, "w", encoding="utf-8") as f:
        json.dump({"uni": uni, "bi": {f"{a} {b}": v for (a, b), v in bi.items()}},
                  f, ensure_ascii=False)
    return uni, bi


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", default=os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        ".lexicon-cache"))
    args = parser.parse_args()
    os.makedirs(args.cache_dir, exist_ok=True)

    print("Loading sources…")
    entries = load_dictionary(args.cache_dir)
    news_uni, news_bi = load_news_stats(args.cache_dir)
    corpus, lyrics_bi = load_corpus(args.cache_dir)
    lyrics_uni = collections.Counter()
    for (cyr, _), n in corpus.items():
        lyrics_uni[cyr] += n
    print(f"  {len(entries)} raw dictionary entries, {len(corpus)} corpus word pairs")

    def frequency(cyr: str) -> int:
        return news_uni.get(cyr, 0) + lyrics_uni.get(cyr, 0)

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
        freq = frequency(cyrillic)
        for key in typed_keys(cyrillic) | {fold_key(latin)}:
            slot = merged.get((key, trad))
            if slot is None or freq > slot[1]:
                merged[(key, trad)] = [cyrillic, freq]

    # ── Merge the corpus: inflected forms + usage counts ─────────────────────
    per_word = {}
    for (cyr, trad), n in corpus.items():
        per_word.setdefault(cyr, []).append((trad, n))
    added = 0
    from_corpus = set()
    for cyr, spellings in per_word.items():
        total = sum(n for _, n in spellings)
        keys = typed_keys(cyr)
        if not keys:
            continue
        for trad, n in spellings:
            if n < MIN_CORPUS_COUNT or n / total < MIN_SPELLING_SHARE:
                continue
            for key in keys:
                if (key, trad) not in merged:
                    merged[(key, trad)] = [cyr, frequency(cyr)]
                    from_corpus.add((key, trad))
                    added += 1
    print(f"  corpus: {added} entries added")

    # Cyrillic typos in the lyrics (баина for байна, хаиртаи for хайртай)
    # converted letter by letter and now share a key with the real word.
    # A spelling that is a tiny fraction of its key's traffic and is not
    # attested in the news corpus is such a typo, not a homophone: drop it.
    by_key = {}
    for (key, trad), (cyr, freq) in merged.items():
        by_key.setdefault(key, []).append((trad, cyr, freq))
    typos = []
    for key, key_entries in by_key.items():
        top = max(f for _, _, f in key_entries)
        for trad, cyr, freq in key_entries:
            if (key, trad) not in from_corpus:
                continue    # dictionary words are never dropped
            if top >= 200 and freq < 0.02 * top and news_uni.get(cyr, 0) < 20:
                del merged[(key, trad)]
                typos.append(f"{key}\t{cyr}\t{freq}\t{top}")
    with open(os.path.join(args.cache_dir, "dropped_typos.tsv"), "w", encoding="utf-8") as f:
        f.write("\n".join(sorted(typos)) + "\n")
    print(f"  dropped {len(typos)} rare same-key spellings (corpus typos; "
          f"listed in {args.cache_dir}/dropped_typos.tsv)")

    rows = sorted(
        (key, trad, cyr, freq)
        for (key, trad), (cyr, freq) in merged.items()
    )
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(LEXICON_PATH, "w", encoding="utf-8", newline="\n") as f:
        for key, trad, cyr, freq in rows:
            f.write(f"{key}\t{trad}\t{cyr}\t{freq}\n")

    ranked = sum(1 for r in rows if r[3] > 0)
    print(f"Wrote {len(rows)} entries to {LEXICON_PATH}")
    print(f"  dropped: {dropped_junk} defective traditional, {dropped_shape} malformed latin/cyrillic")
    print(f"  {ranked} entries carry corpus frequency, {len({r[2] for r in rows})} distinct Cyrillic forms")

    # ── Next-word table ─────────────────────────────────────────────────────
    # The most frequent traditional spelling of every Cyrillic form we know.
    best = {}
    for (key, trad), (cyr, freq) in merged.items():
        if cyr not in best or freq > best[cyr][0]:
            best[cyr] = (freq, trad)
    successors = collections.defaultdict(collections.Counter)
    for (a, b), n in news_bi.items():
        if a in best and b in best:
            successors[a][b] += n
    for (a, b), n in lyrics_bi.items():
        if a in best and b in best:
            successors[a][b] += n
    bigram_rows = []
    for a, counts in successors.items():
        if frequency(a) < MIN_HEAD_FREQ:
            continue
        for b, n in counts.most_common(TOP_SUCCESSORS):
            if n >= MIN_BIGRAM:
                bigram_rows.append((a, best[b][1], b, n))
    bigram_rows.sort(key=lambda r: (r[0], -r[3], r[2]))
    with open(BIGRAMS_PATH, "w", encoding="utf-8", newline="\n") as f:
        for a, trad, b, n in bigram_rows:
            f.write(f"{a}\t{trad}\t{b}\t{n}\n")
    print(f"Wrote {len(bigram_rows)} next-word rows for "
          f"{len({r[0] for r in bigram_rows})} head words to {BIGRAMS_PATH}")


if __name__ == "__main__":
    main()
