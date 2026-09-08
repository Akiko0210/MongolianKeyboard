# How MongolKey turns typed Latin (Cyrillic-based) into Mongol bichig

Cyrillic Mongolian is spelled by sound; traditional script (Mongol bichig)
is spelled by history. A Cyrillic word and its script form differ letter by
letter, so the keyboard never converts letter by letter when it can avoid it.
The conversion runs through these layers, first hit wins:

| Layer | What it knows | Where |
| ----- | ------------- | ----- |
| 1. Dictionary | 52,324 verified spellings for 44,915 Cyrillic word forms (28k dictionary words + 22k corpus forms: case-suffixed nouns, conjugated verbs) | `Resources/lexicon.tsv`, built by `tools/generate_lexicon.py` |
| 2. Suffix and verb rules | how a case, plural, possessive or tense suffix is written after a known stem — every rule checked against 79k corpus lines | `SuffixEngine.swift`, `VerbEngine.swift`, checked by `tools/verify_corpus.py` |
| 3. Learned letter rules | how each typed letter is written in context, for a stem the dictionary lacks (5,904 rules learned from the dictionary; 34% of held-out words exact) | `Resources/orthography.tsv`, `OrthographyConverter.swift`, built by `tools/learn_orthography.py` |
| 4. Letter by letter | the plain transliteration table, always offered as the last candidate | `TransliterationScheme.swift` |

Layers 1 and 2 give *dictionary* candidates (captioned in Cyrillic). Layers
3 and 4 give *guesses* (captioned in Latin) and never pose as a dictionary word.

## 1. Reading what the user typed

People romanize Cyrillic inconsistently, so every dictionary word is indexed
under every key people plausibly type, and the typed buffer is folded with the
same rules (`LatinKey.fold` and `tools/generate_lexicon.py: typed_keys`):

| Cyrillic | Recognized typings | Example |
| -------- | ------------------ | ------- |
| х | h, kh, x, q | hair = xair = khair → хайр |
| ц / ч / ш / ж / з | ts or c / ch / sh / j / z | cag = tsag → цаг |
| в | v, w | |
| ө, ү, у | u; ö/ü/oe/ue; ө also as o (loose tier) | udur = ödör = odor → өдөр |
| й, ы, ь, ъ | i or y; ы also ii; ь/ъ also dropped | sayn = sain; nohoy = nohoi; amdral = amidral; han → хан and хань |
| я, ё, ю, е | ya, yo, yu, ye; long forms doubled or not; е also e | yuu = yu → юу; erunhii = yerunhii → ерөнхий |
| long vowels | doubled, or single (loose tier) | uchlaarai → уучлаарай |

Loose matches (o/u merged, doubled vowels collapsed) always rank below exact
ones, and a spelling seen only a few times next to a common one is treated as
a misspelling of it.

## 2. Why the script is not the Cyrillic letters

Correspondences the dictionary and the learned rules embody (Cyrillic → script,
classical romanization in parentheses):

- **Long vowels are written with a silent ᠭ:** аа → ᠠᠭᠠ (aγa), оо → ᠣᠭᠣ, уу → ᠤᠭᠤ, ээ → ᠡᠭᠡ, өө → ᠥᠭᠡ, үү → ᠦᠭᠦ. But many long vowels are contractions of older syllables, which the script keeps: уул → ᠠᠭᠤᠯᠠ (aγula), сургууль → ᠰᠤᠷᠭᠠᠭᠤᠯᠢ (surγaγuli).
- **Diphthongs take ᠶᠢ:** ай → ᠠᠶᠢ (сайн → ᠰᠠᠶᠢᠨ sayin), ой → ᠣᠶᠢ, уй → ᠤᠶᠢ, эй → ᠡᠶᠢ; but нохой → ᠨᠣᠬᠠᠢ (noqai), хайр → ᠬᠠᠶᠢᠷ᠎ᠠ.
- **Vowels Cyrillic dropped are kept:** амьдрал → ᠠᠮᠢᠳᠤᠷᠠᠯ (amidural), ус → ᠤᠰᠤ (usu), мод → ᠮᠣᠳᠣ (modo), хот → ᠬᠣᠲᠠ (qota), аав → ᠠᠪᠤ (abu), хүн → ᠬᠦᠮᠦᠨ (kümün), өдөр → ᠡᠳᠦᠷ (edür). Which words carry such a vowel is not predictable from Cyrillic: this is exactly what the dictionary is for.
- **Consonants:** в → ᠪ in native words (явах → ᠶᠠᠪᠤᠬᠤ), ᠸ only in loanwords; ц and ч → ᠴ; ж and з → ᠵ; ш → ᠰᠢ (багш → ᠪᠠᠭᠰᠢ, шинэ → ᠰᠢᠨ᠎ᠡ); х → ᠬ; г → ᠭ; нг → ᠩᠭ (монгол → ᠮᠣᠩᠭᠣᠯ mongγol); н before г/х/к → ᠩ (ерөнхий → ᠶᠡᠷᠦᠩᠬᠡᠢ).
- **Iotated vowels:** я → ᠶᠠ, ё → ᠶᠣ, ю → ᠶᠤ/ᠶᠦ, е → ᠶᠡ (ерөнхий) or ᠡ after a consonant.
- **Vowel harmony:** a word with а/о/у (я/ё/ю) is masculine and takes ᠠ/ᠤ suffix vowels; a word with only э/ө/ү (и) is feminine and takes ᠡ/ᠦ. In Unicode, ᠣ/ᠤ and ᠥ/ᠦ look identical after the first syllable; the dictionary carries the encoding the source used.
- **Format characters:** the separated final a/e is `<consonant, U+180E MVS, ᠠ/ᠡ>` with no nirugu (байна → ᠪᠠᠶᠢᠨ᠎ᠠ, шинэ → ᠰᠢᠨ᠎ᠡ, бага → ᠪᠠᠭ᠎ᠠ); free variation selectors U+180B–D pick glyph variants where the source uses them; detached suffixes are joined to the stem with U+202F (narrow no-break space), which is what makes the font draw the suffix-initial forms.

## 3. Noun suffixes (SuffixEngine, corpus-verified)

The written form depends on the stem's *last written letter* (vowel, ᠨ, the
soft consonants ᠨ ᠩ ᠮ ᠯ, or another consonant) and on harmony. Counts in
parentheses are corpus occurrences of the example.

| Cyrillic suffix | After a vowel | After ᠨ | After ᠨ ᠩ ᠮ ᠯ | After other consonants | Examples |
| --- | --- | --- | --- | --- | --- |
| Genitive -ын/-ийн/-ы/-ий | ᠶᠢᠨ | ᠤ / ᠦ (bare) | ᠤᠨ / ᠦᠨ | ᠤᠨ / ᠦᠨ | аавын ᠠᠪᠤ ᠶᠢᠨ (188); хааны ᠬᠠᠭᠠᠨ ᠤ (11); хүний ᠬᠦᠮᠦᠨ ᠦ (756); монголын ᠮᠣᠩᠭᠣᠯ ᠤᠨ (139); гэрийн ᠭᠡᠷ ᠦᠨ (67); нохойн ᠨᠣᠬᠠᠢ ᠶᠢᠨ |
| Accusative -ыг/-ийг/-г | ᠶᠢ | ᠢ | ᠢ | ᠢ | аавыг ᠠᠪᠤ ᠶᠢ; дүүг ᠳᠡᠭᠦᠦ ᠶᠢ; монголыг ᠮᠣᠩᠭᠣᠯ ᠢ; гэрийг ᠭᠡᠷ ᠢ |
| Dative-locative -д/-т/-ад | ᠳᠤ / ᠳᠦ | ᠳᠤ / ᠳᠦ | ᠳᠤ / ᠳᠦ | ᠲᠤ / ᠲᠦ | аавд ᠠᠪᠤ ᠳᠤ; хаанд ᠬᠠᠭᠠᠨ ᠳᠤ; монголд ᠮᠣᠩᠭᠣᠯ ᠳᠤ (46); номд ᠨᠣᠮ ᠳᠤ; гэрт ᠭᠡᠷ ᠲᠦ (47); цагт ᠴᠠᠭ ᠲᠤ (221); улсад ᠤᠯᠤᠰ ᠲᠤ |
| Ablative -аас/-ээс/-оос/-өөс | ᠠᠴᠠ / ᠡᠴᠡ | same | same | same | ааваас ᠠᠪᠤ ᠠᠴᠠ; гэрээс ᠭᠡᠷ ᠡᠴᠡ (17) |
| Instrumental -аар/-ээр/-оор/-өөр | ᠪᠠᠷ / ᠪᠡᠷ | ᠢᠶᠠᠷ / ᠢᠶᠡᠷ | same | same | ааваар ᠠᠪᠤ ᠪᠠᠷ; монголоор ᠮᠣᠩᠭᠣᠯ ᠢᠶᠠᠷ; гэрээр ᠭᠡᠷ ᠢᠶᠡᠷ |
| Comitative -тай/-тэй/-той | ᠲᠠᠢ / ᠲᠡᠢ | same | same | same | аавтай ᠠᠪᠤ ᠲᠠᠢ (13); гэртэй ᠭᠡᠷ ᠲᠡᠢ |
| Reflexive -аа/-ээ/-оо/-өө | ᠪᠠᠨ / ᠪᠡᠨ | ᠢᠶᠠᠨ / ᠢᠶᠡᠨ | same | same | ааваа ᠠᠪᠤ ᠪᠠᠨ (81); гэрээ ᠭᠡᠷ ᠢᠶᠡᠨ (21); монголоо ᠮᠣᠩᠭᠣᠯ ᠢᠶᠠᠨ |
| Plural -нууд | ᠨᠤᠭᠤᠳ / ᠨᠦᠭᠦᠳ | | | | нохойнууд ᠨᠣᠬᠠᠢ ᠨᠤᠭᠤᠳ |
| Plural -ууд/-үүд | ᠨᠤᠭᠤᠳ / ᠨᠦᠭᠦᠳ | ᠤᠳ / ᠦᠳ | ᠤᠳ / ᠦᠳ | ᠤᠳ / ᠦᠳ | номууд ᠨᠣᠮ ᠤᠳ |
| Plural -чууд | ᠴᠤᠳ / ᠴᠦᠳ, attached | | | | монголчууд ᠮᠣᠩᠭᠣᠯᠴᠤᠳ (40) |
| Negation -гүй | ᠦᠭᠡᠢ, detached | same | same | same | аавгүй ᠠᠪᠤ ᠦᠭᠡᠢ |

**Hidden n.** Many stems end in an n the Cyrillic nominative drops; the
suffixed Cyrillic shows it (модны, усанд, уснаас) and the script restores it
on the stem: модны → ᠮᠣᠳᠣᠨ ᠤ, усанд → ᠤᠰᠤᠨ ᠳᠤ (1,246 corpus cases), уснаас →
ᠤᠰᠤᠨ ᠠᠴᠠ.

**Stacked suffixes** are two detached words, not a fused ending:

| Cyrillic | Script | Example |
| --- | --- | --- |
| -даа / -тээ (dative + reflexive) | ᠳᠤ ᠪᠠᠨ / ᠲᠦ ᠪᠡᠨ (never ᠳᠠᠭᠠᠨ) | аавдаа ᠠᠪᠤ ᠳᠤ ᠪᠠᠨ (45); гэртээ ᠭᠡᠷ ᠲᠦ ᠪᠡᠨ (132) |
| -ынхаа (genitive + reflexive) | ᠶᠢᠨ ᠢᠶᠠᠨ | аавынхаа ᠠᠪᠤ ᠶᠢᠨ ᠢᠶᠠᠨ (34) |
| -тайгаа | ᠲᠠᠢ ᠪᠠᠨ | аавтайгаа ᠠᠪᠤ ᠲᠠᠢ ᠪᠠᠨ |
| -аасаа | ᠠᠴᠠ ᠪᠠᠨ | ааваасаа ᠠᠪᠤ ᠠᠴᠠ ᠪᠠᠨ |
| -аараа / -ээрээ | ᠢᠶᠠᠷ ᠢᠶᠠᠨ / ᠢᠶᠡᠷ ᠢᠶᠡᠨ | гэрээрээ ᠭᠡᠷ ᠢᠶᠡᠷ ᠢᠶᠡᠨ |

**Dropped stem vowel.** Cyrillic drops a short vowel before a vowel-initial
suffix; the script keeps it: бодол → бодлын = ᠪᠣᠳᠣᠯ ᠤᠨ, гурав → гурван =
ᠭᠤᠷᠪᠠᠨ. When a typed stem is unknown and ends in two consonants, the engine
restores the vowel and looks the stem up again.

**Pronouns** decline irregularly and come only from the dictionary: би → надад
ᠨᠠᠳᠠ ᠳᠤ, чи → чамд ᠴᠢᠮ᠎ᠠ ᠳᠤ; the rules never touch би, чи, та, бид, энэ, тэр.

## 4. Verb suffixes (VerbEngine, corpus-verified)

The stem is the infinitive minus ᠬᠤ/ᠬᠦ (явах ᠶᠠᠪᠤᠬᠤ → ᠶᠠᠪᠤ-). Vowel-final
stems attach the suffix directly; consonant-final stems (ᠠᠪ-, ᠣᠯ-, ᠭᠠᠷ-)
insert a connective ᠤ/ᠦ before most suffixes.

| Cyrillic | Script | Notes | Examples |
| --- | --- | --- | --- |
| -сан/-сэн/-сон/-сөн | ᠭᠰᠠᠨ / ᠭᠰᠡᠨ | + connective after a consonant | явсан ᠶᠠᠪᠤᠭᠰᠠᠨ (6,349); авсан ᠠᠪᠤᠭᠰᠠᠨ; ирсэн ᠢᠷᠡᠭᠰᠡᠨ |
| -на/-нэ/-но/-нө | ᠨ᠎ᠠ / ᠨ᠎ᠡ (MVS) | + connective | явна ᠶᠠᠪᠤᠨ᠎ᠠ (8,154); авна ᠠᠪᠤᠨ᠎ᠠ; ирнэ ᠢᠷᠡᠨ᠎ᠡ; болно ᠪᠣᠯᠤᠨ᠎ᠠ |
| -ж / -ч | ᠵᠤ / ᠵᠦ after a vowel or ᠨ ᠩ ᠮ ᠯ; ᠴᠤ / ᠴᠦ after other consonants | | явж ᠶᠠᠪᠤᠵᠤ (7,250); олж ᠣᠯᠵᠤ; авч ᠠᠪᠴᠤ; гарч ᠭᠠᠷᠴᠤ |
| -даг/-дэг | ᠳᠠᠭ / ᠳᠡᠭ | never a connective, never ᠲ | явдаг ᠶᠠᠪᠤᠳᠠᠭ; авдаг ᠠᠪᠳᠠᠭ; гардаг ᠭᠠᠷᠳᠠᠭ |
| -аад/-ээд | ᠭᠠᠳ / ᠭᠡᠳ | + connective | яваад ᠶᠠᠪᠤᠭᠠᠳ; аваад ᠠᠪᠤᠭᠠᠳ |
| -лаа/-лээ | ᠯ᠎ᠠ / ᠯ᠎ᠡ (MVS) | + connective | явлаа ᠶᠠᠪᠤᠯ᠎ᠠ; авлаа ᠠᠪᠤᠯ᠎ᠠ |
| -жээ/-чээ | ᠵᠠᠢ / ᠴᠠᠢ | same split as -ж/-ч | |
| -в | ᠪᠠ / ᠪᠡ | connective only after ᠪ/ᠭ | болов ᠪᠣᠯᠪᠠ; авав ᠠᠪᠤᠪᠠ |
| -ъя/-ье/-я | ᠶ᠎ᠠ / ᠶ᠎ᠡ (MVS) | + connective | явъя ᠶᠠᠪᠤᠶ᠎ᠠ (87) |
| -маар/-мээр | ᠮᠠᠷ / ᠮᠡᠷ | + connective | явмаар ᠶᠠᠪᠤᠮᠠᠷ |
| -гаа/-гээ | ᠭ᠎ᠠ / ᠭ᠎ᠡ (MVS) | vowel stems only | байгаа ᠪᠠᠶᠢᠭ᠎ᠠ (779) |
| -аарай/-ээрэй | ᠭᠠᠷᠠᠢ / ᠭᠡᠷᠡᠢ | + connective | |
| -хгүй | infinitive + ᠦᠭᠡᠢ (detached) | | явахгүй ᠶᠠᠪᠤᠬᠤ ᠦᠭᠡᠢ (2,962) |
| -сангүй, -даггүй | ᠭᠰᠠᠨ ᠦᠭᠡᠢ, ᠳᠠᠭ ᠦᠭᠡᠢ | | |

Irregular verbs come from the dictionary and always rank first: гэсэн ᠭᠡᠰᠡᠨ,
өгсөн ᠥᠭᠭᠦᠭᠰᠡᠨ, байжээ ᠪᠠᠶᠢᠴᠠᠢ.

## 5. Learned letter rules for unknown stems

For a stem the dictionary lacks (a name, a new word), each typed letter is
written according to its neighbours and the word's harmony class, using rules
extracted automatically from the 37,000 stem spellings in the dictionary
(`tools/learn_orthography.py`). They reproduce the regular correspondences
(sain → ᠰᠠᠶᠢᠨ, bagsh → ᠪᠠᠭᠰᠢ, amidral → ᠠᠮᠢᠳᠤᠷᠠᠯ, medeelel → ᠮᠡᠳᠡᠭᠡᠯᠡᠯ) and fail
where the script keeps something Cyrillic does not show (aav → ᠠᠪᠤ, nohoi →
ᠨᠣᠬᠠᠢ). Measured on held-out dictionary words: 34% exact whole words. A known
suffix is split off first and attached by the verified rules of section 3, so
batbold + ийн → ᠪᠠᠲᠤᠪᠣᠯᠣᠳᠠ ᠶᠢᠨ has a correct genitive even when the stem is a
guess. These candidates are captioned with the typed Latin, never with a
Cyrillic word.

## 6. Ranking and prediction

Homophones (уг / үг / өг all typed `ug`) are ordered by how often each form
occurs in 23.7M words of news plus the lyrics corpus, and, once a word has been
committed, by what usually follows it (after монгол, улсын comes first). The
same counts drive the next-word predictions shown after each commit.

## 7. How this is verified

- `python3 tools/verify_corpus.py` prints, for every suffix, how the corpus
  writes it after each stem-final letter with counts; every rule above cites
  those tables.
- `SuffixEngineTests`, `SuggestionEngineTests`, `InputSessionTests` and
  `PhraseSpellerTests` pin the examples in this document (133 tests, run on
  every push).
- Corpus spellings are machine-converted (Inner Mongolia University's
  converter over song lyrics) and the dictionary is a community dataset; a
  native speaker's review of their own errors is the remaining step.
