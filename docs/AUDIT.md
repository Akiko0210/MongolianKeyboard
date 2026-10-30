# Repository audit — 2026-09-19

This audit fixes specific defects and records evidence. It does not certify all
Mongolian spelling, every iOS host application, or App Store acceptance.

## Changes

- Added exact Cyrillic lookup and an all-35-letter Cyrillic keyboard. This prevents
  Latin homophone folding from changing үг into уг. Latin and Cyrillic input share
  the dictionary-backed pipeline and preserve unknown or unsupported input.
- Space now commits a stored match or the original text. Generated morphology,
  statistical spelling and literal transliteration require a candidate tap and
  have source labels. Long input is bounded before suggestion work.
- Reviewed 16 independent spelling examples against a government-hosted handbook,
  aligned three stored choices with it, and updated corresponding prediction rows.
  Corrected suffix harmony selection to inspect the written stem. These changes
  do not validate the remaining legacy dictionary or the full heuristic morphology.
- Fixed composition handling when the host changes text/selection; it no longer
  inserts a buffered word from a host-change callback. Explicit alphabet/globe
  switching commits while the insertion point is known. Delete repetition avoids
  an extra deletion on release; Return labels follow the host field.
- Added two named font choices above candidates. Replaced per-glyph manual spacing
  with whole-word Core Text shaping. Suffix groups and zero-advance selectors keep
  their shaped positions, and joined words are not split between columns.
- Added privacy manifests and bundled font notices to app and extension, corrected
  keyboard capability metadata, and documented accurate platform restrictions.
- Added an offline detailed conversion guide. Fixed CI test-status propagation so
  a logging pipeline cannot hide a failed xcodebuild test run.

## Executed checks

Environment: macOS on Apple silicon, Xcode 16.4, iOS 18.5 build SDK, iOS 18.6
Simulator runtime. Local builds are ad-hoc signed for Simulator. No Developer Team
is configured for distribution.

| Check | Result and scope |
| --- | --- |
| Original SwiftPM suite | 133 passed before changes |
| Final SwiftPM engine suite | 141 passed, zero failures |
| iOS engine and native rendering/layout suite | 146 passed, zero failures: the same 141 engine cases plus 5 native tests |
| Container UI test | Passed: setup, converter typing, reference and privacy tabs |
| Actual extension UI test | Passed: Latin/Cyrillic words, exact separators, predictions, both fonts, numbers, unchanged unknown input, delete, Return and landscape typing |
| Core Text probe | Both bundled faces load and shape the exercised words; sample PNGs visually inspected |
| Resource structural scan | 52,324 rows checked for malformed keys, negative frequencies, replacement characters and malformed suffix separators; this is not semantic spelling validation |
| Built app/extension preflight | Passed privacy declarations, fonts/notices, tables, guide, matching versions and extension metadata |
| Submission preflight | Fails intentionally: current SDK is not a submission SDK and legacy data rights are unresolved |
| CI configuration | YAML parsed, shell blocks syntax-checked, failing pipeline status checked with exit 23; remote CI matrix not executed here |
| Repository hygiene | Python tools compile, property lists lint and git diff whitespace checks pass |

The independently sourced spelling fixture is
[`orthography-review.json`](../Packages/MongolEngine/Tests/MongolEngineTests/Fixtures/orthography-review.json).
The engine's older tests also exercise legacy expected output; their success is
not independent linguistic evidence. See [ORTHOGRAPHY.md](ORTHOGRAPHY.md) for the
source pages, precise decision rules and remaining ambiguity.

## Local artifacts and UI history

Generated artifacts are ignored by git and remain in the local `build` directory:

- `build/VerifiedAudit.xcresult`: passing 146-test native/engine target. The combined
  UI portion failed while another application took over the shared simulator;
  the overall result bundle is therefore failed, not a clean full-suite pass.
- `build/AuditKeyboardFinal.xcresult`: passing actual keyboard UI test before the
  final deletion/Return/landscape assertions were added.
- `build/audit-screenshots`: exported evidence of both faces and Cyrillic keys.
- `build/shape-audit`: font probe output.
- `build/IsolatedAudit.xcresult`: container UI test passed on a dedicated iPhone
  16 Pro; extension setup failed on an invalid Settings accessibility activation
  point. The harness now taps the visible row frame instead.
- `build/KeyboardComplete.xcresult`: final expanded extension UI test passed,
  one test with zero failures (147 seconds), on the dedicated simulator.
- `build/verified-screenshots`: final screenshots, including `dashitseden.png`,
  `noto-sans.png`, `cyrillic.png` and `landscape.png`.

Earlier UI runs exposed unreliable Settings navigation, an offscreen field tap
that scrolled without focusing, and a false-positive system-keyboard check. The
harness now uses the extension's identifiers, visible Settings row frames and
waits for an onscreen keyboard after refocusing. A narrowed run with an incorrect
test selector executed zero tests and is not counted. The native and two UI
results above passed in separate runs; no failed aggregate is represented as a
clean full-suite pass.

## Remaining work before release

1. Resolve language-data redistribution rights or replace the uncleared data;
   details in [DATA_PROVENANCE.md](DATA_PROVENANCE.md).
2. Expand independent spelling review, especially suffixes, irregulars, names,
   homographs and the unreviewed corpus. The current 16-word fixture cannot prove
   correctness of 52,324 stored forms.
3. Test actual iPhone/iPad devices and the requested social/Google apps using
   [COMPATIBILITY.md](COMPATIBILITY.md). No such third-party app is claimed tested.
4. Build/archive with Apple's accepted Xcode/iOS SDK, configure signing and store
   metadata, validate and submit for Apple's review. See [RELEASE.md](RELEASE.md).

Font selection affects the app and keyboard previews. Other apps control their
text rendering. Secure fields, phone pads and apps that refuse custom keyboards
remain outside the extension's control.
