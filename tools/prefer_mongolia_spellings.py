#!/usr/bin/env python3
"""
Rank the Mongolia-convention spelling first where the lexicon already holds it
and the only difference from the current default is ᠣ<->ᠤ or ᠥ<->ᠦ.

Product decision (issue #21): the reference standard is Mongolia's. Both bulk
sources of stored spellings were produced by Inner Mongolia University's
converter, trans.mglip.com: the lyrics corpus (generate_lexicon.py says so)
and the npm word list (its own updater calls
http://trans.mglip.com/CyrillicC2T.aspx, in written-mongol-keyboard 1.3.5,
dist/database/updater/config.d.ts). Homographs were then ranked by lyrics
counts (628d638), so wherever both encodings exist, the converter's choice
wins by construction.

The one Mongolia-side source in the repository is the 2023 government
handbook (nccd.gov.mn, Fixtures/orthography-review.json), whose
transliterations decide two such cases: одоо ᠣᠳᠤ and мөөг ᠮᠥᠭᠦ. The converter
gives ᠣᠳᠣ and ᠮᠥᠭᠥ; Greg Eck's CC0 table (suragch/mongolian-datasets/eck),
which does not come from that converter, gives the handbook's spelling in
both. So for this one class of difference, a spelling Eck gives is taken as
the Mongolia-convention one.

Scope, deliberately narrow:
  * only words whose lexicon rows already include Eck's spelling (compared
    ignoring FVS/MVS) — no spelling is added;
  * only when it differs from the current default solely by ᠣ->ᠤ or ᠥ->ᠦ
    after the first vowel letter, the position and direction of both
    handbook cases. These pairs share glyphs in running text, so nothing
    changes on screen; the encoded text follows the handbook convention.
    Visible differences (ᠶᠢ/ᠢ, length) are not touched: no Mongolia-side
    evidence decides them.
  * apply_reviewed_spellings.py runs afterwards, so the handbook still wins.

The promoted row takes the old default's frequency (the two are swapped; on
a tie the promoted row gets +1), so ranking changes and the frequency totals
do not. Next-word rows that carry the old spelling are updated to the new one.

    python3 tools/prefer_mongolia_spellings.py            # apply
    python3 tools/prefer_mongolia_spellings.py --report   # list, change nothing
"""

import argparse
import collections
import sys
import unicodedata
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from fetch_authority import SOURCES, fetch  # noqa: E402

RESOURCES = HERE.parent / "Packages/MongolEngine/Sources/MongolEngine/Resources"
FORMAT = {0x180B, 0x180C, 0x180D, 0x180E, 0x180F}
TO_U = {("ᠣ", "ᠤ"), ("ᠥ", "ᠦ")}


def bare(text):
    return "".join(c for c in unicodedata.normalize("NFC", text) if ord(c) not in FORMAT)


def o_to_u(old, new):
    """True when `new` differs from `old` only by ᠣ->ᠤ or ᠥ->ᠦ after the first
    vowel letter: the position and direction of both handbook cases
    (ᠣᠳᠣ->ᠣᠳᠤ, ᠮᠥᠭᠥ->ᠮᠥᠭᠦ). First-syllable differences (охин ᠥᠬᠢᠨ/ᠦᠬᠢᠨ)
    and the reverse direction (дундговь ᠭᠤᠪᠢ/ᠭᠣᠪᠢ) have no such evidence."""
    old, new = bare(old), bare(new)
    if old == new or len(old) != len(new):
        return False
    first_vowel = next((i for i, c in enumerate(old) if 0x1820 <= ord(c) <= 0x1827), None)
    if first_vowel is None:
        return False
    return all(x == y or ((x, y) in TO_U and i > first_vowel)
               for i, (x, y) in enumerate(zip(old, new)))


def default_of(rows):
    """Same order as SuggestionEngine.exactRank for one Cyrillic word."""
    return min(rows, key=lambda r: (-int(r[3]), len(r[2]), r[1]))


def plan(lexicon_lines):
    eck = collections.defaultdict(set)
    for cyr, uni in SOURCES["eck"]["parse"](fetch("eck", SOURCES["eck"])):
        eck[cyr].add(bare(uni))
    groups = collections.defaultdict(list)
    for line in lexicon_lines:
        cols = line.split("\t")
        if len(cols) == 4:
            groups[cols[2]].append(cols)
    changes = {}
    for cyr, rows in groups.items():
        if len({r[1] for r in rows}) < 2 or cyr not in eck:
            continue
        old = default_of(rows)
        if bare(old[1]) in eck[cyr]:
            continue
        better = [r for r in rows if bare(r[1]) in eck[cyr] and o_to_u(old[1], r[1])]
        if better:
            new = default_of(better)
            changes[cyr] = (old[1], int(old[3]), new[1], int(new[3]))
    return changes


def apply(report_only=False):
    lexicon = RESOURCES / "lexicon.tsv"
    bigrams = RESOURCES / "bigrams.tsv"
    lines = lexicon.read_text(encoding="utf-8").splitlines()
    changes = plan(lines)
    if report_only:
        for cyr, (old, of, new, nf) in sorted(changes.items(), key=lambda x: -x[1][1]):
            print(f"{cyr}\t{old} ({of})\t->\t{new} ({nf})")
        print(f"# {len(changes)} words would change default")
        return len(changes)
    out = []
    for line in lines:
        cols = line.split("\t")
        if len(cols) == 4 and cols[2] in changes:
            old, of, new, nf = changes[cols[2]]
            if cols[1] == new:
                cols[3] = str(of + 1 if of == nf else of)
            elif cols[1] == old:
                cols[3] = str(nf)
        out.append("\t".join(cols))
    lexicon.write_text("\n".join(out) + "\n", encoding="utf-8")
    b_out, b_changed = [], 0
    for line in bigrams.read_text(encoding="utf-8").splitlines():
        cols = line.split("\t")
        if len(cols) == 4 and cols[2] in changes and cols[1] == changes[cols[2]][0]:
            cols[1] = changes[cols[2]][2]
            b_changed += 1
        b_out.append("\t".join(cols))
    bigrams.write_text("\n".join(b_out) + "\n", encoding="utf-8")
    print(f"Mongolia convention: {len(changes)} defaults re-ranked, {b_changed} next-word spellings updated")
    return len(changes)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", action="store_true")
    apply(report_only=ap.parse_args().report)
