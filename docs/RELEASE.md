# Shipping MongolKey so people can install it

A keyboard extension can only reach other people's iPhones through Apple.
There is no sideloading path for the general public. The steps below take the
project from this repo to a keyboard anyone can enable under
**Settings ▸ General ▸ Keyboard ▸ Keyboards** and use in every app.

## 1. Apple Developer Program (once)

- Enroll at <https://developer.apple.com/programs/> (US$99/year). This is
  required for TestFlight and the App Store; nothing else works around it.
- In Xcode ▸ Settings ▸ Accounts, sign in with that Apple ID.

## 2. Point the project at your team

Edit `project.yml`: set `DEVELOPMENT_TEAM` to your 10-character Team ID
(Membership page of the developer site) and, if you want, change the
`bundleIdPrefix` from `com.mongolkey` to your own reverse-domain prefix.
Then `xcodegen generate`.

Both targets (the app and the `MongolKeyboard` extension) sign with the same
team automatically. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in
`project.yml` for every upload; App Store Connect rejects reused build numbers.

## 3. Create the app record

App Store Connect ▸ My Apps ▸ **+** ▸ New App. Bundle ID = the container app
(`com.mongolkey.app` or your prefix + `.app`). The extension needs no separate
record; it ships inside the app.

Required metadata for a keyboard: a privacy policy URL (this repo's
`PRIVACY.md` published anywhere public is enough), screenshots for the
6.7-inch and 6.1-inch iPhone sizes, and the App Privacy answers
("Data Not Collected" — the keyboard has no network access and never requests
Full Access).

## 4. Archive and upload

In Xcode: select the **MongolKey** scheme, destination **Any iOS Device**,
then Product ▸ **Archive**. In the Organizer window choose **Distribute App ▸
App Store Connect ▸ Upload**. Xcode signs, validates and uploads.

Command line equivalent, from the repo root:

```sh
xcodegen generate
xcodebuild -project MongolKey.xcodeproj -scheme MongolKey -configuration Release \
  -destination "generic/platform=iOS" -archivePath build/MongolKey.xcarchive archive
xcodebuild -exportArchive -archivePath build/MongolKey.xcarchive \
  -exportOptionsPlist tools/ExportOptions.plist -exportPath build/export
# then upload build/export/MongolKey.ipa with Transporter.app or:
xcrun altool --upload-app -f build/export/MongolKey.ipa -t ios --apiKey KEY --apiIssuer ISSUER
```

`tools/ExportOptions.plist` needs `method` = `app-store-connect` and your
`teamID`.

## 5. TestFlight first

Once the build finishes processing (10–30 minutes), add it to a TestFlight
group. Testers install the TestFlight app, accept the invite, and then enable
MongolKey exactly like any App Store keyboard. Use this for the native-speaker
orthography review before going public.

## 6. App Store review notes

Reviewers test keyboards manually. In the review notes say: no Full Access,
no network, offline dictionary; how to enable it; and a few words to type
(`mongol`, `sain`, `aavdaa`) with the expected script. Keyboards that offer
nothing without the container app are rejected, which is why the app has
its own romanizer and reference tabs.

## What ships inside

| Piece | Size | Notes |
| --- | --- | --- |
| Lexicon (`lexicon.tsv`) | 1.5 MB | 27,957 words, loaded once per keyboard session on a background queue |
| Noto Sans Mongolian | 0.3 MB | bundled in both app and extension |
| Extension binary | ~1 MB | pure Swift, no dependencies |

The extension stays far under Apple's memory limit for keyboards; every
keystroke does two binary searches and a bounded top-k scan, no allocation
of the whole candidate list.
