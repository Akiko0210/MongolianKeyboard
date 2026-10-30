# MongolKey

An offline iOS keyboard for traditional Mongolian script, with Latin and Cyrillic
input and two preview fonts: Classical Mongolian Dashitseden and Noto Sans Mongolian.
It also includes a standalone phrase converter and an offline spelling guide.

## Using it

Enable MongolKey in Settings → General → Keyboard → Keyboards → Add New Keyboard.
Use the globe to select it. Full Access is not needed.

- Type `mongol` or `монгол`; dictionary candidates appear vertically.
- Tap **A/Б** to switch Latin/Cyrillic keys. The Cyrillic layout includes all 35 letters.
- Choose either font using the two named controls above the candidate bar.
- Space commits a dictionary match. Unknown words stay unchanged; generated
  spellings are labeled **Generated · check** and require a tap.
- Read the Cyrillic captions: Latin input can represent several different words.
- Font choice changes previews in MongolKey. Receiving apps choose their own font
  and text direction for the Unicode text you send.

Custom keyboards work in eligible text fields. iOS excludes password and phone-pad
fields, and apps can disable third-party keyboards. Compatibility with particular
versions of Instagram, Facebook, Messenger, WhatsApp and Google apps still needs
physical-device testing. See [the compatibility record](docs/COMPATIBILITY.md).

## Spelling and evidence

Traditional spelling cannot be recovered reliably by replacing modern letters.
The engine uses whole-word lookup, with generated morphology and letter rules
available as explicitly selected alternatives. Direct Cyrillic lookup preserves
у/ү/ө distinctions that Latin keys can lose.

The legacy lexicon contains 52,324 lookup rows, including machine-converted corpus
forms. It is **not an entirely verified dictionary**. Sixteen examples were checked
against a government-hosted teaching handbook, and three stored choices were
aligned with that source. [The detailed specification](docs/ORTHOGRAPHY.md) explains
every stage, character ordering, suffix tables, ranking, sources and limitations.
It is also available in the app's Reference tab.

## Build and test

For local development: macOS, Xcode 16.4 or newer, and XcodeGen. For App Store
submission: **Xcode 26 or newer and the iOS 26 SDK**, per Apple's current requirement.

```sh
brew install xcodegen
xcodegen generate
open MongolKey.xcodeproj
swift test --package-path Packages/MongolEngine
```

Select the MongolKey scheme and an installed simulator. The generated Xcode project
is intentionally untracked; edit `project.yml`. To run engine and UI tests:

```sh
xcodebuild test -project MongolKey.xcodeproj -scheme MongolKey \
  -destination 'platform=iOS Simulator,id=YOUR_DEDICATED_SIMULATOR_UUID' \
  -parallel-testing-enabled NO CODE_SIGN_IDENTITY=-
```

See [audit results](docs/AUDIT.md), [testing tools](docs/TESTING.md),
[release requirements](docs/RELEASE.md), [privacy](PRIVACY.md), and
[data provenance](docs/DATA_PROVENANCE.md). The audit does not constitute App Store
approval; distribution rights for legacy language data remain unresolved.

## Layout

- `Packages/MongolEngine`: pure Swift conversion, dictionaries, morphology and tests.
- `Keyboard`: UIKit custom keyboard extension, candidate bar and input lifecycle.
- `App/MongolKey`: SwiftUI setup, phrase converter, reference and privacy screens.
- `Shared`: Core Text rendering, fonts, notices and privacy manifest.
- `tools`: data generation, reviewed spelling corrections and simulator diagnostics.

All runtime conversion stays on device. Only font preferences are persisted, in
separate app and extension settings. There is no analytics, keyboard networking,
clipboard access or shared keystroke storage.
