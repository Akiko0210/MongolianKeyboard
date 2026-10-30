#!/usr/bin/env python3
"""Apply the documented review to lexicon and predictions, including rebuilds."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Packages/MongolEngine/Sources/MongolEngine/Resources"


def apply():
    review = json.loads((ROOT / "Packages/MongolEngine/Tests/MongolEngineTests/Fixtures/orthography-review.json").read_text())
    replacements = {row["cyrillic"]: row["traditional"]
                    for row in review["examples"] if row.get("replace")}
    for name in ("lexicon.tsv", "bigrams.tsv"):
        path = RESOURCES / name
        rows = []
        changed = 0
        for line in path.read_text().splitlines():
            fields = line.split("\t")
            if len(fields) == 4 and fields[2] in replacements:
                replacement = replacements[fields[2]]
                changed += fields[1] != replacement
                fields[1] = replacement
            rows.append("\t".join(fields))
        path.write_text("\n".join(rows) + "\n")
        print(f"{name}: {changed} reviewed spellings applied")


if __name__ == "__main__":
    apply()
