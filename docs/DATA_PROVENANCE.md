# Language data and font rights

Audit date: 2026-09-19. This inventory describes what is present; it is not a
legal clearance or a statement that every stored spelling is correct.

| Asset | Provenance | Evidence and unresolved issue |
| --- | --- | --- |
| Base word list | `written-mongol-keyboard` npm 1.3.5, author sura0111 | The downloaded package declares MIT in `package.json`; no license file covering the dictionary was found in that tarball. Obtain the applicable copyright/permission notice and confirm dictionary redistribution rights. A package metadata string alone does not resolve underlying data rights. |
| Additional word forms | `tugstugi/mongolian-nlp/bichig2cyrillic/lyrics.txt.gz` | Machine-converted song lyrics. No applicable redistribution grant was established from the repository documentation. Review rights before distribution. |
| Frequency and prediction counts | Same repository, `datasets/eduge.csv.gz`, plus lyrics | Repository credits Bolorsoft for the news dataset; an applicable distribution grant for these derived tables was not established. |
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
