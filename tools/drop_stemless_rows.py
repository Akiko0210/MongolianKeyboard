#!/usr/bin/env python3
"""
Drop lexicon rows whose traditional spelling has no stem, and the next-word
rows that point at them. Idempotent; generate_lexicon.py runs it after every
rebuild so a regeneration cannot bring the rows back.

These rows come from tokens split off numerals and initials in the corpora
(2-ны, 15-нд, "Б. Батболд") and from lyric lines the converter misaligned.
Before this filter, typing ын and pressing Space committed U+180D U+202F ᠤᠨ:
a variation selector with no letter in front of it, then a bare suffix.

A row is dropped when its spelling meets one of three mechanical tests:

  leading-format   It starts with FVS1-3, MVS or NNBSP. A free variation
                   selector chooses a variant of the *preceding* character,
                   and NNBSP separates a suffix from the stem before it
                   (Unicode Standard, ch. 13.5 Mongolian; StandardizedVariants.txt
                   lists every FVS sequence as <letter, FVS>). With nothing
                   before it, neither has anything to apply to.
  suffix-no-stem   It has a detached suffix (NNBSP) and the part before the
                   first NNBSP contains no vowel letter (U+1820-U+1827):
                   ᠨ+ᠤ for ны, ᠪ+ᠤᠧ for бые, ᠨᠳ+ᠤ+ᠬᠢ for надых.
  lone-consonant   Both the Cyrillic and the script are one consonant letter
                   (д -> ᠳ, б -> ᠪ). The particles л (ᠯᠠ) and ч (ᠴᠤ) are
                   spelled with a vowel and are not touched.

Not removed, because the test cannot tell them from real abbreviations:
vowel-less multi-letter rows such as км (ᠺᠮ), тв (ᠲᠪ), нд (ᠨᠳ). They are
listed by --report for a reviewer.

    python3 tools/drop_stemless_rows.py            # apply
    python3 tools/drop_stemless_rows.py --report   # list, change nothing
"""

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Packages/MongolEngine/Sources/MongolEngine/Resources"

NNBSP = " "
FORMAT = {0x180B, 0x180C, 0x180D, 0x180E, 0x180F, 0x202F}
VOWELS = range(0x1820, 0x1828)
LETTERS = range(0x1820, 0x1843)
CYRILLIC_VOWELS = set("аэиоуөүыяеёю")


def has_vowel(text):
    return any(ord(c) in VOWELS for c in text)


def reason(traditional, cyrillic):
    """Why this spelling is stemless, or None if it is not."""
    if not traditional:
        return None
    if ord(traditional[0]) in FORMAT:
        return "leading-format"
    if NNBSP in traditional and not has_vowel(traditional.split(NNBSP)[0]):
        return "suffix-no-stem"
    letters = [c for c in traditional if ord(c) in LETTERS]
    if (len(cyrillic) == 1 and cyrillic not in CYRILLIC_VOWELS
            and len(letters) == 1 and not has_vowel(traditional)):
        return "lone-consonant"
    return None


def visible(text):
    return "".join(c if ord(c) not in FORMAT else f"<U+{ord(c):04X}>" for c in text)


def apply(report_only=False, log=None):
    lexicon = RESOURCES / "lexicon.tsv"
    bigrams = RESOURCES / "bigrams.tsv"
    kept, dropped, suspects = [], [], []
    for line in lexicon.read_text(encoding="utf-8").splitlines():
        cols = line.split("\t")
        why = reason(cols[1], cols[2]) if len(cols) == 4 else None
        if why:
            dropped.append((why, cols))
        else:
            kept.append(line)
            if len(cols) == 4 and not has_vowel(cols[1]) and not any(c in CYRILLIC_VOWELS for c in cols[2]):
                suspects.append(cols)

    surviving = {line.split("\t")[2] for line in kept if line.count("\t") == 3}
    bad_spellings = {cols[1] for _, cols in dropped}
    bigram_kept, bigram_dropped = [], 0
    for line in bigrams.read_text(encoding="utf-8").splitlines():
        cols = line.split("\t")
        if len(cols) == 4 and (cols[1] in bad_spellings or cols[0] not in surviving
                               or reason(cols[1], cols[2])):
            bigram_dropped += 1
        else:
            bigram_kept.append(line)

    if report_only:
        for why, cols in dropped:
            print(f"{why}\t{cols[2]}\t{visible(cols[1])}\t{cols[0]}\t{cols[3]}")
        print(f"# would drop {len(dropped)} lexicon rows, {bigram_dropped} next-word rows")
        print(f"# kept for review (vowel-less, maybe an abbreviation): "
              + ", ".join(sorted({c[2] for c in suspects})))
        return len(dropped), bigram_dropped

    if dropped:
        lexicon.write_text("\n".join(kept) + "\n", encoding="utf-8")
    if bigram_dropped:
        bigrams.write_text("\n".join(bigram_kept) + "\n", encoding="utf-8")
    if log and dropped:
        with open(log, "w", encoding="utf-8") as fh:
            fh.write("# reason\tkey\ttraditional\tcyrillic\tfrequency  (removed by tools/drop_stemless_rows.py)\n")
            for why, cols in dropped:
                fh.write(f"{why}\t{cols[0]}\t{cols[1]}\t{cols[2]}\t{cols[3]}\n")
    print(f"stemless rows: dropped {len(dropped)} lexicon rows, {bigram_dropped} next-word rows")
    return len(dropped), bigram_dropped


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", action="store_true", help="list what would be dropped; change nothing")
    ap.add_argument("--log", help="write the dropped lexicon rows to this TSV")
    args = ap.parse_args()
    apply(report_only=args.report, log=args.log)
    sys.exit(0)
