# Language data and font rights

## Shipped build: licence-clean (issue #20, 2026-11-19)

The bundled tables are now built by `python3 tools/generate_lexicon.py --licence-clean`
and `python3 tools/learn_orthography.py --lexicon .lexicon-cache/clean-training.tsv`.
Nothing in them derives from `tugstugi/mongolian-nlp`. `DATA_SOURCES.txt`, bundled in
the app and the keyboard, records the build, the attributions and the MIT notice, and
`tools/release_preflight.py --submission` fails any bundle not marked `licence-clean`.

| Table | Built from | Licence and obligation |
| --- | --- | --- |
| `lexicon.tsv` words and spellings | `written-mongol-keyboard` 1.3.5 (sura0111) | MIT as declared in `package.json`. Notice reproduced in `DATA_SOURCES.txt`. Residual risk: the package carries no separate licence file for the data. |
| `lexicon.tsv` additional words | `suragch/mongolian-datasets` mazaalai | CC0-1.0. No obligation; credited anyway. Frequency 0, so dictionary spellings rank first. |
| `lexicon.tsv` frequencies, `bigrams.tsv` | Mongolian Wikipedia dump (`tools/build_wikipedia_corpus.py` input) | CC BY-SA 4.0. Attribution in `DATA_SOURCES.txt` and in the app's Reference tab (`ORTHOGRAPHY.md`). Only counts ship; the derived tables are shared under the same licence. |
| `orthography.tsv` | Learned from the `written-mongol-keyboard` rows only | Inherits MIT. CC0 rows are left out of training because they made the rules worse on common words. |

The legacy tables below can still be rebuilt with `tools/generate_lexicon.py` (no flag),
which marks them `build: legacy`. They stay blocked until the licence request in
`docs/licence-request-draft.md` is answered.

## Legacy inventory (2026-09-19 audit)

Audit date: 2026-09-19. This inventory describes what is present; it is not a
legal clearance or a statement that every stored spelling is correct.

| Asset | Provenance | Evidence and unresolved issue |
| --- | --- | --- |
| Base word list | `written-mongol-keyboard` npm 1.3.5, author sura0111 | The downloaded package declares MIT in `package.json`; no license file covering the dictionary was found in that tarball. Obtain the applicable copyright/permission notice and confirm dictionary redistribution rights. A package metadata string alone does not resolve underlying data rights. |
| Additional word forms | `tugstugi/mongolian-nlp/bichig2cyrillic/lyrics.txt.gz` | Machine-converted song lyrics. No applicable redistribution grant was established from the repository documentation. Review rights before distribution. |
| Frequency and prediction counts | Same repository, `datasets/eduge.csv.gz`, plus lyrics | Repository credits Bolorsoft for the news dataset; an applicable distribution grant for these derived tables was not established. |
| Imported dictionary rows (15,593) | `suragch/mongolian-datasets` `mazaalai` table, via `tools/fetch_authority.py` (recorded in `docs/authority.tsv`) | CC0-1.0 public-domain dedication, so no redistribution question. Single-source and not reviewed by a native speaker; disagrees with the legacy lexicon on 26% of shared words. Rows carry frequency 0 so attested spellings rank first. |
| `orthography.tsv` | Learned from the combined legacy lexicon | Derived model inherits unresolved provenance questions. Existing reported accuracy is not an independent grammar validation. |
| 16 review examples | Government-hosted 2023 teaching handbook, page references in the test fixture | Small attributed spelling regression sample, not a redistribution of the book. Unicode transcriptions are recorded with their source; no government endorsement is claimed. |
| Noto Sans Mongolian | Bundled font, Noto Project Authors | SIL OFL 1.1 notice is bundled in both application and extension. Preserve its copyright and license conditions. |
| Classical Mongolian Dashitseden | Bundled font, T. Jamyansuren / Bolorsoft | Embedded name-table license permits free personal/commercial use and distribution. Font is unmodified; its embedded notice is retained. See `Shared/Fonts/LICENSES.md`. |

Source records: [npm package metadata](https://registry.npmjs.org/written-mongol-keyboard/1.3.5),
[base dictionary project](https://github.com/sura0111/writtenMongolianKeyboard),
[corpus provider's README](https://github.com/tugstugi/mongolian-nlp/blob/master/README.md).
These are provenance references, **not sources used to establish official grammar**.

The broad legacy datasets were retained for development and regression testing.
Do not represent the current bundle as cleared for public distribution. Before
submission, obtain and bundle applicable notices/permission, or replace the
uncleared data and retrain the derived table. Do not copy an unrelated MIT license
onto these assets. The source spelling review is described in [ORTHOGRAPHY.md](ORTHOGRAPHY.md).

`tools/generate_lexicon.py` builds the legacy tables and then applies the explicit
reviewed corrections. `tools/apply_reviewed_spellings.py` can also be run separately
and is idempotent. Existing downloads are not pinned by content hash, so fresh
upstream corpus downloads may change results. Preserve the committed resources
for reproducible app builds; do not silently regenerate them for a release.
