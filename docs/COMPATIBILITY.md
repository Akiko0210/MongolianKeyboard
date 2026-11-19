# iOS compatibility and verification

MongolKey commits plain Unicode through `UITextDocumentProxy.insertText` and
removes text through `deleteBackward`. It does not identify host apps, use private
integration hooks, replace text through the clipboard, or require Full Access.
MVS, FVS and narrow no-break suffix spaces are retained in the inserted string.

This is the system integration path for eligible native and web text fields.
It cannot guarantee every app accepts or correctly renders that text. Password
and phone-pad fields use system keyboards; an app may disable custom keyboards.
The receiving app selects fonts and writing direction. These are platform and
host-app boundaries, not settings the extension can override.
[Apple's custom keyboard guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html).

## Test record

See [AUDIT.md](AUDIT.md) for completed checks, environment and result bundles.
Use the table below to track **physical-device** checks; blank app versions are
not evidence of support. Simulator tests do not stand in for these applications.

| Target | Fields to exercise | Physical-device status |
| --- | --- | --- |
| Instagram | Caption, comment, DM, search | Not tested; app/account not available in this environment |
| Facebook | Post, comment, search | Not tested |
| Messenger | Message, reply, multiline compose | Not tested |
| WhatsApp | Message, reply, multiline compose | Not tested |
| Gmail | Subject, body, recipient boundary | Not tested |
| Google Docs | Document body, selection, paste round trip | Not tested |
| Google Search / Chrome | Search, HTML input, textarea, contenteditable | Not tested |
| Apple Messages / Notes | Compose, reply, note | Physical device not tested |
| Apps refusing custom keyboards | Confirm system fallback | Expected system restriction; requires a representative host |
| Secure / phone fields | Confirm system keyboard replaces extension | Platform restriction; requires device verification |

For each tested app record app version, iOS version, device, field type and result.
Use a private draft or your own test conversation; sending to other people is not
necessary. Check the string again after saving/reopening the draft.

## Round-trip cases

- `mongol` / `монгол` → `ᠮᠣᠩᠭᠣᠯ`.
- `sain` / `сайн` → `ᠰᠠᠶᠢᠨ`.
- `үг` must produce `ᠦᠭᠡ`, not the higher-frequency Latin homophone уг.
- `baina` / `байна` → `ᠪᠠᠶᠢᠨ\u{180E}ᠠ`; no missing-glyph box or stripped separator.
- `aavdaa` / `аавдаа` → `ᠠᠪᠤ\u{202F}ᠳᠤ\u{202F}ᠪᠠᠨ` using the stored legacy form.
- `zzz` stays `zzz` on Space; generated candidates require a tap.
- Ordinary spaces, Mongolian punctuation, Return, delete, hold-delete, emoji next
  to script, cursor movement, selection replacement and switching fields.
- Select both preview fonts while composing. Confirm the preview changes but
  committed scalars do not. Receiving-app appearance may remain the same.
- Portrait/landscape, iPad floating/full-size keyboard, light/dark, VoiceOver,
  long words, extension termination/relaunch, and Full Access left off.

A layout should not split a joined written word halfway down a column. A host
that lays script horizontally, substitutes a font, or strips formatting scalars
needs an entry here; the extension cannot repair that host's text renderer.
