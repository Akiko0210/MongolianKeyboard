# Bundled fonts

## Classical Mongolian Dashitseden — `ClassicalMongolianDashitseden.ttf`

- **Family:** Classical Mongolian Dashitseden, version 5.91
- **Designer:** T. Jamyansuren
- **Copyright:** © 2008 Bolorsoft LLC. All Rights Reserved.
- **Trademark:** "Classical Mongolian Dashitseden" is a trademark of Bolorsoft LLC.
- **Source:** <https://fonts.bolorsoft.com/web/cmdashitseden.ttf>
- **Licence** (verbatim from the font's own `name` table, ID 13):

  > Bolorsoft free font. This font may be downloaded, distributed and used
  > free of charge for both personal and commercial use. Any other use is
  > prohibited.

  The licence URL recorded in the font (<https://fonts.bolorsoft.com/license>)
  returns 404, so the string above is the only licence text available. It
  permits redistribution and commercial use, which is what bundling in this app
  relies on. It does **not** grant the right to modify or resell the font.

  This is the face bolor-toli.com renders Mongol bichig with.

## Noto Sans Mongolian — `NotoSansMongolian-Regular.ttf`

- **Licence:** SIL Open Font License 1.1 — see `OFL.txt`.
- Kept as the fallback face: OFL places no restrictions on redistribution,
  modification, or bundling.

## Known rendering difference

Dashitseden covers 60 code points in the Mongolian block (U+1800–U+18AF);
Noto Sans Mongolian covers 158. Everything Dashitseden omits is **Todo, Sibe,
Manchu or Ali Gali** (U+1843–U+1877, U+1880–U+18AA) — other languages written
in Mongolian script, not Mongolian proper. Every lexicon entry stays within
what Dashitseden covers, and all free variation selectors (U+180B–U+180D),
MVS (U+180E) and the suffix separator NNBSP (U+202F) are mapped.

**U+180E MONGOLIAN VOWEL SEPARATOR** (the separated final a/e of байна,
бага, шинэ — thousands of lexicon entries) was once seen drawing a
missing-glyph box under Dashitseden. Verified since:

- The font itself handles it: HarfBuzz shapes `ᠪᠠᠶᠢᠨ᠎ᠠ` into the font's
  dedicated separated-vowel forms (`uniE275` + `uniE214`), the MVS glyph
  being an empty 77-unit glyph consumed by the font's own rules.
- CoreText does the same: `tools/ShapeProbe.swift` (run by CI on macOS 26)
  picks exactly those glyph ids for байна, бага, шинэ and ᠴᠢᠮ᠎ᠠ, uses no
  fallback font, and its rendered PNGs show the separated vowel, no box.

So the keyboard passes the text to CoreText unchanged for both faces. If a
box ever reappears on some iOS version, `tools/ShapeProbe.swift` is the tool
to pin down what that version does with U+180E.
