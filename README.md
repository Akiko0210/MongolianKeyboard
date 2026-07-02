# MongolKey — Mongolian Script Keyboard for iOS

A QWERTY-based transliteration input method for **traditional Mongolian script**
(*Mongol bichig*), built as a native iOS Custom Keyboard Extension. Type the
sounds in Latin letters — e.g. `gar` — and the engine emits correct Mongolian
Unicode, shown **vertically** as you type, the way Pinyin made Chinese
accessible on a QWERTY keyboard.

This repository implements **v1** as described in `PROJECT_DESCRIPTION.md`.

<p>
  <img alt="Composing bar showing gar → ᠭᠠᠷ" src="docs/keyboard-composing.png" width="280">
</p>

---

## What works (verified)

Verified by unit tests and by running the app + keyboard in the iOS Simulator
(iPhone 17, iOS 26):

- **Transliteration engine** — longest-match tokenizer, digraph detection
  (`ng kh gh ch sh ts oe ue`), composing buffer with token-level backspace.
  **31 unit tests pass** (`swift test`).
- **Keyboard extension** — system-style QWERTY grid, a CJK-inspired composing
  bar that shows the Latin buffer **and** the composed Mongolian rendered
  vertically, a numbers/punctuation layer (incl. Mongolian `᠂` `᠃`), globe key,
  backspace with tap-and-hold repeat, key popups.
- **Vertical rendering** — `Core Text` vertical layout (`vertical-lr`) with
  correct OpenType shaping via bundled Noto Sans Mongolian.
- **Container app** — onboarding, a live romanizer (works without enabling the
  keyboard), a keyboard tester with a vertical mirror, the full reference table
  (generated from the engine), and the privacy screen.
- **No Full Access** — no network, no pasteboard, no shared storage.

---

## Architecture

Three components, matching `PROJECT_DESCRIPTION.md §7`:

```
Packages/MongolEngine/     Pure Swift package (no UIKit) — the transliteration
                           engine + longest-match tokenizer + scheme. Unit-tested.

Keyboard/                  UIInputViewController keyboard extension. Delegates all
                           transliteration to MongolEngine; renders the QWERTY grid
                           and the vertical composing bar.

App/MongolKey/             SwiftUI container app (onboarding, try-it, reference,
                           privacy). Shares MongolEngine for the live romanizer.

Shared/Rendering/          VerticalMongolianView (Core Text) + MongolFont loader,
                           compiled into both the app and the extension.

Shared/Fonts/              NotoSansMongolian-Regular.ttf (SIL OFL) + license.
```

The engine has **no UIKit dependency**, so it is testable with plain XCTest and
reusable on macOS/watchOS later (`§12.6`).

---

## Building

Requirements: Xcode 16+ (developed on Xcode 26), macOS, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

The Xcode project is generated from `project.yml` (it is git-ignored):

```sh
xcodegen generate
open MongolKey.xcodeproj
```

Or from the command line:

```sh
# Engine unit tests (fast, no simulator)
cd Packages/MongolEngine && swift test

# Build app + keyboard for a simulator
xcodegen generate
xcodebuild -project MongolKey.xcodeproj -scheme MongolKey \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO build
```

To run: install on a simulator, then enable the keyboard in
**Settings ▸ General ▸ Keyboard ▸ Keyboards ▸ Add New Keyboard ▸ MongolKey**,
and switch to it with the 🌐 key. The in-app **Setup** tab walks through this.

---

## Transliteration scheme (v1)

One scheme ships in v1 (`§9`). It is phonetic-first with digraphs matched before
their component letters. The draft table in `PROJECT_DESCRIPTION.md §9` had a few
conflicting rows (three different meanings for `kh`); those were resolved so
every Latin key is unambiguous. The scheme lives in
`Packages/MongolEngine/Sources/MongolEngine/TransliterationScheme.swift` and is
the single source of truth for both the keyboard and the in-app reference table.

| Type | Type this | Get | Notes |
|---|---|---|---|
| Vowels | `a e i o u` | ᠠ ᠡ ᠢ ᠣ ᠤ | |
| | `oe`/`ö`, `ue`/`ü` | ᠥ ᠦ | |
| Digraphs | `ng kh gh ch sh ts` | ᠩ ᠬ ᠭ ᠴ ᠱ ᠼ | matched before single letters |
| Consonants | `n b p q g m l s t d j y r w/v f k z h` | … | see the in-app Reference tab |

> The scheme is a solid v1 starting point. Per `§15`, native-speaker
> orthographic sign-off (Phase 8) is a separate human step that will refine the
> table; the tests assert the engine's *contract*, not linguistic authority.

---

## Known limitations (v1)

Per `PROJECT_DESCRIPTION.md §19`: host apps display the inserted text
horizontally (only the keyboard's preview bar and the app's views show it
vertically); no FVS glyph-variant selection; one scheme; no autocorrect.

---

## Privacy

No data collected. No Full Access. See [PRIVACY.md](PRIVACY.md).

## Font license

Noto Sans Mongolian is licensed under the SIL Open Font License 1.1. See
[`Shared/Fonts/OFL.txt`](Shared/Fonts/OFL.txt).
