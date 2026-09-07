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
in Mongolian script, not Mongolian proper. All 27,957 lexicon entries stay
within what Dashitseden covers, and all four free variation selectors
(U+180B–U+180D) plus MVS (U+180E) are mapped.

One visible difference remains: entries containing **U+180E MONGOLIAN VOWEL
SEPARATOR** — 1,246 of 27,957 rows, 4.5%, e.g. `бага` `ᠪᠠᠭ᠎᠊ᠠ` — draw a
missing-glyph box in the candidate bar under Dashitseden, where Noto renders
them cleanly. U+180E is in Dashitseden's `cmap`, but the font predates Unicode
6.3's reclassification of it from a space to a format character, so CoreText
resolves it to a visible glyph. bolor-toli.com does not hit this because the
web text engine handles U+180E differently.

Switch that view to Noto Sans in Try It ▸ Typeface to compare. If the box
proves annoying in daily use, the fix is to strip U+180E before shaping when
`face == .dashitseden`, rather than to drop the font.
