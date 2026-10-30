# MongolKey spelling and conversion specification

Reviewed 2026-09-19. This is the implementation specification, including its
limits, and is bundled in the app under Reference → Full conversion guide.
It describes orthographic conversion and candidate selection. It is not a
complete Mongolian grammar or a sentence-level grammar checker.

## What was independently checked

The 2023 **Монгол бичгийн гарын авлага - I**, hosted by a Mongolian government
agency, distinguishes masculine а/о/у, feminine э/ө/ү and neutral и; neutral-only
words inflect with feminine forms. Modern long vowels can correspond to
vowel–consonant–vowel, adjacent vowels, or one historical vowel. Its diphthong
chapter also gives more than one written pattern. These are reasons to look up
whole words, not insert a fixed character between every doubled vowel.
[Government handbook, PDF pages 31, 39–40, 44–50](https://www.nccd.gov.mn/stat/file/u/Surgalt/mongolbichig.pdf).

Sixteen examples from PDF pages 44, 48 and 49 are transcribed into
[the review fixture](../Packages/MongolEngine/Tests/MongolEngineTests/Fixtures/orthography-review.json).
They test both Cyrillic conversion and availability among Latin candidates.
Three stored spellings were aligned with the handbook: сүү → ᠰᠦᠨ (its explicit
sun form), мөөг → ᠮᠥᠭᠦ, одоо → ᠣᠳᠤ. This does not establish that every alternative
usage is invalid. Font glyphs cannot by themselves distinguish all vowel scalars;
the handbook's accompanying transliterations were also consulted.

The government's [Cyrillic spelling rules](https://toli.gov.mn/r) cover Cyrillic
orthography, including vowel loss and suffix attachment. They are not a
character substitution specification for traditional script. The Academy's
[description of its dictionary](https://mas.ac.mn/post/20440) establishes a useful
institutional reference; this audit did not import that site's entire dictionary.
The [government case-suffix lesson](https://burtgel.gov.mn/post/58575) embeds a
video; its title alone was not treated as validation of our suffix tables.

The rest of this document describes **our code and existing data**. The 52,324
lookup rows are not all government-verified. Legacy data includes an npm word
list and machine-converted lyrics. Repeated converter output is evidence of
consistency, not independent proof of correct spelling. Legacy statistical
rules, arbitrary names, irregular forms and ambiguous words still require review.

## The decision pipeline

1. Keep the typed word in memory. Nothing is inserted into the host mid-word.
2. Normalize lookup keys to NFC and lowercase. Keep original input for fallback.
3. If the token contains Cyrillic, require a wholly Mongolian-Cyrillic token and
   search the **Cyrillic index directly**. Do not turn it into Latin first.
4. Otherwise accept ASCII Latin plus ö/ü, and apply the Latin lookup folds below.
5. Offer dictionary matches, generated inflections, loose Latin matches,
   generated spellings, literal letter transliteration, then completions.
   Equal script strings are displayed once. Cyrillic offers exact matches;
   if absent, it offers only generated inflections whose Cyrillic caption
   exactly equals the normalized input, plus unchanged input.
6. Space, punctuation and Return commit the first dictionary or loose match.
   If none exists, they preserve the input. Generated spellings and literal
   transliterations require an explicit tap. Completions and predictions are
   always tap-only. A candidate tap commits that candidate and one ordinary space.
7. Tokens longer than 64 characters bypass suggestion work and stay unchanged.
   Mixed alphabets and unsupported letters also stay unchanged.

A caption saying “Dictionary” means a stored spelling, **not official approval**.
“Loose match” changes the lookup tolerance. “Generated · check” means an
algorithm has constructed a spelling. “Letter by letter” means a mechanical
mapping. “Keep input” preserves what was typed. These labels are shown in the
candidate bar and read by VoiceOver.

### Why direct Cyrillic lookup matters

The Latin key `ug` can name уг, үг or өг. Direct input `үг` selects only dictionary
entries captioned үг, producing ᠦᠭᠡ. It must not become уг merely because уг has a
higher corpus count. The same protection applies to у/ү/ө and long-vowel
contrasts. Capitalization does not change the lookup; traditional output has no
Cyrillic uppercase form. Unknown Cyrillic input is preserved in its original form.

`CyrillicKey.foldedLatin` is used only to search for possible generated morphology.
It merges у/ө/ү to `u`, й/ь/ъ to `i`, ы to `ii`, and maps я/ё/ю/е to ya/yo/yu/ye.
That mapping is lossy and is never the exact Cyrillic lookup key.

### Latin lookup conventions

These are keyboard input conventions, not government spelling rules.

| Typed sequence | Lookup fold | Consequence |
| --- | --- | --- |
| ö, ü, oe, ue | u | Multiple Cyrillic readings remain possible |
| kh, q, x | h | Common ways to type х |
| w | v | Common ways to type в |
| c except before h | ts | ц; preserve ch as a unit |
| y except before a/e/i/o/u | i | sayn = sain; nohoy = nohoi |
| gh | unchanged | Can represent a real g+h boundary |
| uppercase, decomposed ö/ü | lowercase NFC | Equivalent Unicode input matches |

The generator also stores alternate keys: dropped ь/ъ, one or two i letters,
iotated long vowels, and е typed e or ye. Loose lookup then merges o/u and
collapses repeated vowels. Loose results rank below exact matches. A loose
candidate can still be the wrong word: its Cyrillic caption lets the user decide.

## Which characters make the written word

The dictionary selects an entire Unicode spelling. It does not derive the word
from the shapes printed on the keys. Examples from the shipped conversion path:

| Input | Selected sequence, in logical order | Result |
| --- | --- | --- |
| aav / аав | A U+1820, BA U+182A, U U+1824 | ᠠᠪᠤ |
| sain / сайн | SA U+1830, A U+1820, YA U+1836, I U+1822, NA U+1828 | ᠰᠠᠶᠢᠨ |
| mongol / монгол | MA U+182E, O U+1823, ANG U+1829, GA U+182D, O U+1823, LA U+182F | ᠮᠣᠩᠭᠣᠯ |
| baina / байна | BA, A, YA, I, NA, MVS U+180E, A | ᠪᠠᠶᠢᠨ᠎ᠠ |

For `aav`, replacing a+a+v separately would miss the stored historical spelling.
For `mongol`, the literal tokenizer consumes `ng` together and does not supply
the following GA: the stored dictionary spelling supplies the full sequence.
These are different paths with deliberately different output.

The first, middle and last **glyph shapes** are selected by Core Text and the
font's shaping tables from the complete character sequence. The engine does
not replace initial letters with private-use pictures or reverse the string.

### Format characters are part of the text

- U+180B–U+180D: free variation selectors present in existing dictionary data.
- U+180E: Mongolian vowel separator before a separated final vowel.
- U+202F: narrow no-break space between the stored stem and a detached suffix.
- U+0020: ordinary space between words, including the space inserted on commit.

They are preserved. Do not strip “invisible characters,” substitute ASCII spaces
for all suffix boundaries, or add variation selectors just to imitate a font.
The app rotates complete Core Text lines for vertical display. It wraps at word
boundaries, keeps NNBSP groups intact, honors newlines, and scales an overlong
word to fit its column. Font choice does not alter these Unicode strings.

## Generated noun forms: exact implemented decisions

These are limited heuristics in `SuffixEngine.swift`, not a certified complete
morphological analyzer. All generated candidates are tap-only.

A typed suffix is split from the end of a Latin lookup key. The remaining key
must identify a dictionary stem. Several possible splits can be offered.
Harmony is taken from the first non-neutral vowel in the **written stem**:
A/O/U → masculine; E/OE/UE/EE → feminine. Detached suffixes are excluded from
that scan. If the stem supplies no deciding vowel, the Cyrillic spelling is
consulted, with a feminine default for neutral-only input. Cyrillic ю by itself
does not force masculine harmony. Loanwords and irregular words need lexical data.

The final written letter ignores FVS, MVS and separators. Define V as a vowel,
N as NA, and S as the set NA/ANG/MA/LA. Here M/F means the masculine/feminine
choice; every separated piece is preceded by U+202F.

| Kind | Selection implemented |
| --- | --- |
| Genitive | after V: ᠶᠢᠨ; after N: ᠤ/ᠦ; otherwise ᠤᠨ/ᠦᠨ |
| Accusative | after V: ᠶᠢ; otherwise ᠢ |
| Dative | after V or S: ᠳᠤ/ᠳᠦ; otherwise ᠲᠤ/ᠲᠦ |
| Ablative | ᠠᠴᠠ/ᠡᠴᠡ |
| Instrumental | after V: ᠪᠠᠷ/ᠪᠡᠷ; otherwise ᠢᠶᠠᠷ/ᠢᠶᠡᠷ |
| Comitative | ᠲᠠᠢ/ᠲᠡᠢ |
| Reflexive | after V: ᠪᠠᠨ/ᠪᠡᠨ; otherwise ᠢᠶᠠᠨ/ᠢᠶᠡᠨ |
| nuud plural | ᠨᠤᠭᠤᠳ/ᠨᠦᠭᠦᠳ |
| uud plural | after V: the nuud form; otherwise ᠤᠳ/ᠦᠳ |
| chuud plural | attach ᠴᠤᠳ/ᠴᠦᠳ directly |
| Negation | separated ᠦᠭᠡᠢ |

The typed endings and allowed harmony classes are listed explicitly in the
`suffixes` array, including forms such as giin/iin/in, iig/ig, d/t, aas/ees,
aar/eer, tai/tei/toi, and their stacked forms.

Hidden-n branches (`ni`, `nii`, `and`, `end`, `ond`, `und`, `naas` and related
forms) can add NA to a vowel-final stem before choosing the suffix. This is a
candidate-generating heuristic: the code lacks a complete lexical inventory of
unstable-n nouns. It must not automatically invent an n for an unreviewed word.
When no ordinary parse succeeds, it tries restoring a lost vowel before the last
consonant and searches the dictionary again. That also lacks a complete Cyrillic
morphophonological model and is not proof that a parse is correct.

Stacked endings are processed in order. The next part uses the last letter of
the preceding suffix: for the implemented dative + reflexive analysis, aavdaa
becomes `ᠠᠪᠤ + NNBSP + ᠳᠤ + NNBSP + ᠪᠠᠨ`. Whole stored forms outrank such
constructed forms. The heuristic pronoun exclusion list is bi/chi/ta/bid/ene/ter/uu;
irregular forms must come from dictionary entries.

## Generated verb forms: exact implemented decisions

`VerbEngine.swift` proposes an infinitive by adding h/ah/eh/oh/uh/ih to the
remainder of the typed key. The dictionary result must end in Cyrillic х and
traditional ᠬᠤ or ᠬᠦ. Removing that traditional ending gives the written stem.
This spelling check is only a heuristic for part of speech; it is not a full
lexical verb classification.

Let C be empty after a written vowel, otherwise ᠤ/ᠦ according to harmony.
Let J be ᠵ after V or S (as above), otherwise ᠴ.

| Kind | What is appended to the written stem |
| --- | --- |
| past san/sen/son/sun | C + ᠭᠰᠠᠨ/ᠭᠰᠡᠨ |
| nonpast na/ne/no/nu | C + ᠨ + MVS + ᠠ/ᠡ |
| converb j/ch | J + ᠤ/ᠦ |
| habitual dag/deg/dog/dug | ᠳᠠᠭ/ᠳᠡᠭ, no C |
| perfective aad/eed/ood/uud | C + ᠭᠠᠳ/ᠭᠡᠳ |
| recent past laa/lee/loo/luu | C + ᠯ + MVS + ᠠ/ᠡ |
| evidential jee/chee | J + ᠠᠢ/ᠡᠢ |
| simple past v/av/ev/ov/uv | C only after BA/GA, then ᠪᠠ/ᠪᠡ |
| voluntative ya/ye and variants | C + ᠶ + MVS + ᠠ/ᠡ |
| desiderative maar/meer/moor/muur | C + ᠮᠠᠷ/ᠮᠡᠷ |
| progressive gaa/gee/goo/guu | vowel stems only: ᠭ + MVS + ᠠ/ᠡ |
| polite imperative aarai/eerei etc. | C + ᠭᠠᠷᠠᠢ/ᠭᠡᠷᠡᠢ |
| negation | infinitive, past or habitual form + NNBSP + ᠦᠭᠡᠢ |

Irregular verbs and exceptions to these patterns are not solved by counting
corpus occurrences. The interface therefore asks the user to select a generated
form deliberately. The previous documentation's absolute statements such as
“never” a different connective or “every suffix verified” were too strong.

## Learned spelling for unknown Latin stems

`tools/learn_orthography.py` aligns existing dictionary keys with script strings
and produces `orthography.tsv`. It is a statistical decision list, not a set of
official grammar rules. The older reported 34% whole-word held-out accuracy was
not rerun in this audit and should not be advertised as a current benchmark.

At runtime ch/sh/ts become temporary symbols C/S/T. For each symbol, look for a
rule using: symbol + previous + next + harmony + next-next; then progressively
shorter contexts in the exact order in `OrthographyConverter.spell`. Start/end
markers are ^/$. Harmony here is inferred from the lossy Latin key, so it is
uncertain. The first matching rule contributes a string, possibly empty.
If any symbol has no rule at all, conversion returns nil instead of silently
dropping that symbol. The engine may try a known suffix with a learned stem
first. All such output is labeled Generated · check and requires a tap.

## Literal letter-by-letter mode

This is an escape hatch for someone who knows the intended written spelling.
It does not restore historical vowels or infer grammar. `Tokenizer` tries the
longest mapping first; backspace removes the last complete token, including a
digraph. Unmapped characters pass through. The in-app Reference table is generated
from `TransliterationScheme.v1`, which is the source of truth.

| Keys | Unicode output |
| --- | --- |
| a e i o u ö/oe ü/ue | 1820 1821 1822 1823 1824 1825 1826 |
| ng kh gh ch sh ts | 1829 182C 182D 1834 1831 183C |
| n b p q g m l s t d | 1828 182A 182B 182C 182D 182E 182F 1830 1832 1833 |
| j y r w/v f k z h | 1835 1836 1837 1838 1839 183A 183D 183E |

These numbers have the U+ prefix. Some keys intentionally represent foreign
letters, so dictionary х versus literal h, or dictionary в versus literal v,
can produce different characters. It is not a general Cyrillic transliterator.

## Ranking, context and lifecycle

Exact Latin matches sort by whether they are likely successors of the previous
word, then stored frequency, Cyrillic length and script-string tie break. Generated
inflections prefer plain stems over already-suffixed ones, then frequency and
longer dictionary coverage. Loose matches fill the dictionary tier up to three,
with frequency thresholds and length distance; completions fill remaining slots.
The nominal candidate limit is eight, but exact matches and fallback choices can
exceed it. Context can reorder existing candidates, not prove intended meaning.

After committing a known word, up to three stored next-word predictions appear.
Punctuation, newline, host deletion, field/selection changes, explicit keyboard
switching and dismissal clear context. Space does not select a next-word
prediction. The phrase converter uses the same context across ordinary spaces
and resets it at other separators.

Host callbacks cancel composition without inserting anything: the old insertion
point may already be invalid. An explicit A/Б or globe action commits while the
current insertion point is known. No composition is saved to disk.

## Reproduction and scope

Run `swift test --package-path Packages/MongolEngine`. The government fixture is
independent of the original corpus; the other older word tests remain useful
regressions but do not constitute external validation. `tools/apply_reviewed_spellings.py`
applies the three reviewed choices to both lexicon and prediction data, and the
generator calls it after regeneration. The learned table remains a legacy model.

A full accuracy release needs a larger independently reviewed set, lexical
exception data, contextual ambiguity evaluation and correction of the remaining
legacy dictionary errors. See [release requirements](RELEASE.md) and
[data provenance and rights](DATA_PROVENANCE.md). No claim of complete grammar,
100% correct conversion, official endorsement or universal app support is made.
