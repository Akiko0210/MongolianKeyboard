# App Store release review

Reviewed against Apple documentation on 2026-09-19. Code changes and simulator
tests are not App Store approval. This repository is **not yet cleared for submission**.

## Fixed in this audit

- Both executables bundle `PrivacyInfo.xcprivacy`: no tracking, no collected data,
  and the UserDefaults reason CA92.1 for private font preferences. There is no
  App Group or cross-app preferences access. Apple requires an API declaration
  in each executable's bundle that uses a required-reason API.
  [Required-reason API documentation](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api),
  [approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).
- `RequestsOpenAccess` remains false. The keyboard provides actual input and a
  next-keyboard mechanism, works offline, and contains no advertising or purchases.
  The globe supports the system input-mode menu when iOS asks us to provide a key.
  [App Review guideline 4.4.1](https://developer.apple.com/app-store/review/guidelines/#extensions).
- `IsASCIICapable` is false: Latin keys compose Mongolian and are not an English
  keyboard. Extension-safe APIs are enforced. The app's Settings button uses
  `UIApplication.openSettingsURLString`; test-only Settings automation is not shipped.
- Font notices are copied into app and extension bundles. Versions come from
  `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`; iPad orientations are explicit.
- Privacy and product copy describe host-app restrictions, preview-only typefaces,
  generated spelling limits, stored preferences and a concrete support URL.

## Outstanding release requirements

1. **Build toolchain.** This Mac has Xcode 16.4 / iOS 18.6 Simulator. Since
   April 28, 2026, uploads require Xcode 26 or later with the iOS 26 SDK or later.
   Install/select the required Xcode, rerun tests and archive with that SDK.
   [Apple's SDK submission requirement](https://developer.apple.com/news/upcoming-requirements/).
2. **Language-data rights.** Obtain the missing permissions/notices or replace
   the affected language data. [DATA_PROVENANCE.md](DATA_PROVENANCE.md) identifies
   the concrete gaps. Do not equate an available GitHub download with distribution
   rights. Apple's IP requirements apply to included assets.
   [Guideline 5.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property).
3. **Physical-device testing.** Test supported iPhone/iPad versions and real
   third-party apps using [COMPATIBILITY.md](COMPATIBILITY.md). Exercise low-memory
   extension restarts, rotation, VoiceOver, font persistence and cursor changes.
   No universal cross-app rendering or memory-limit guarantee is made.
4. **Signing and metadata.** Set your Developer Team and identifiers, archive,
   validate in Organizer, create the App Store Connect record, supply actual device
   screenshots, support and publicly reachable privacy-policy URLs, complete the
   current age-rating/privacy/export-compliance questionnaires, and submit for review.
   Claim no data collected only while the implementation remains as documented.
5. **Accuracy review.** Expand the independent spelling set and review ambiguous
   entries and generated forms with a qualified reader before marketing broad
   accuracy. Do not advertise “all words verified,” government endorsement,
   guaranteed support in every app, or font styles that travel with sent text.

The repository includes the 1024-pixel app icon. Deployment remains iOS 16+;
Apple's SDK requirement concerns the build toolchain, not the minimum device OS.
This environment has no configured signing team; no archive was submitted.

## Reproducible local checks

```sh
xcodegen generate
swift test --package-path Packages/MongolEngine
xcodebuild test -project MongolKey.xcodeproj -scheme MongolKey \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -parallel-testing-enabled NO CODE_SIGN_IDENTITY=-
python3 tools/release_preflight.py --app build/Audit/Build/Products/Debug-iphonesimulator/MongolKey.app
```

The preflight checks the actual built bundles. `--submission` also checks the
submission SDK and reports the unresolved data-rights block; a local build pass
must not be presented as release clearance.

For a signed archive after resolving the requirements:

```sh
xcodebuild -project MongolKey.xcodeproj -scheme MongolKey -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/MongolKey.xcarchive archive
```

Use Organizer → Validate App → Distribute App for TestFlight/App Store Connect.
These steps require the account's team, certificates and completed metadata.

## Suggested reviewer notes

MongolKey is an offline traditional Mongolian keyboard. Enable it under Settings →
General → Keyboard → Keyboards → Add New Keyboard → MongolKey, then select it with
the globe. Full Access is not requested. Type `mongol` and Space for ᠮᠣᠩᠭᠣᠯ; tap
A/Б for Cyrillic input and type `үг` for ᠦᠭᠡ. The Dashitseden/Noto Sans controls
change previews only. Unknown input stays unchanged unless a candidate is selected.
The containing app independently converts Latin/Cyrillic phrases and includes an
offline spelling guide and privacy information. Password and phone-pad fields
use Apple's keyboard as required by iOS.
