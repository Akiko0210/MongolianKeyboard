# Testing MongolKey on an iPhone 13 Pro screen

MongolKey is a native iOS app plus a keyboard *extension*, so the only faithful
way to see it "as on the phone" is Apple's own iOS Simulator. Pick the route
that matches your laptop:

| Your laptop | Fastest route | Interactive? |
| ----------- | ------------- | ------------ |
| Mac | `tools/simulate.sh` (Xcode Simulator, real iPhone 13 Pro device profile) | Yes, full |
| Windows / Linux / Chromebook | GitHub Actions builds it, then **Appetize.io** streams a real simulator into your browser | Yes, full |
| Any (just want to look) | GitHub Actions screenshots artifact | No, PNGs of every screen incl. the keyboard |

No Apple developer account is needed for any of these.

---

## 1. Mac: one command

Prerequisites (once): Xcode 16 or newer from the App Store, then

```sh
xcode-select --install          # command-line tools, if you never ran Xcode
brew install xcodegen
```

Then, from the repo root:

```sh
tools/simulate.sh
```

The script regenerates the Xcode project, builds the app + extension, creates a
simulator named **"MongolKey iPhone 13 Pro"** on the newest installed iOS
runtime (falling back to the same-sized iPhone 14 / iPhone 13 if your Xcode no
longer ships the 13 Pro profile — it prints which one it used), boots it,
installs, and launches the app in the Simulator window at the phone's real
390 × 844 pt size. Press **⌘1 / ⌘2 / ⌘3** in Simulator to change zoom.

Enable the keyboard once per fresh install — this is a Settings action Apple
does not let scripts perform:

1. In the simulator: **Settings ▸ General ▸ Keyboard ▸ Keyboards ▸ Add New
   Keyboard… ▸ MongolKey**.
2. Back in MongolKey ▸ **Try It**, tap the "Type here with MongolKey…" field,
   hold **🌐** and pick **MongolKey**, then type `mongol`, `sain`, `khaan`.
   On **iOS 26** the globe is no longer inside the keyboard: it sits in the
   system bar *below* the keyboard, bottom-left, next to the microphone.
   Hold it there and slide to "MongolKey".

Tip: if the simulator's on-screen keyboard never appears, uncheck
**I/O ▸ Keyboard ▸ Connect Hardware Keyboard** in the Simulator menu.

Useful variants:

```sh
tools/simulate.sh --device "iPhone 17"      # another device profile
tools/simulate.sh --skip-generate           # you only edited Swift files
cd Packages/MongolEngine && swift test      # engine tests, ~1 s, no simulator
```

Or use the Xcode GUI: `xcodegen generate`, `open MongolKey.xcodeproj`, pick the
**MongolKey** scheme and the **MongolKey iPhone 13 Pro** destination, ⌘R.

---

## 2. Windows / Linux: GitHub Actions + Appetize.io (browser)

There is no iOS Simulator for Windows or Linux, and "iOS emulators" advertised
for PC cannot run a real keyboard extension. The workable approach is to have
GitHub's free macOS runners build the app and then run that build in a cloud
simulator you control from the browser.

### 2a. Build in the cloud (already set up)

Every push runs [`.github/workflows/ios-simulator.yml`](../.github/workflows/ios-simulator.yml)
on a `macos-26` runner. It:

- runs the engine unit tests,
- builds a universal (arm64 + x86_64) simulator `MongolKey.app`,
- creates an iPhone 13 Pro simulator, installs the app and runs the XCUITests
  in `UITests/`, which tap through every tab, open Settings to enable the
  keyboard, switch to MongolKey and type sample words — saving a PNG at each step,
- uploads `MongolKey.app.zip`, the screenshots and the test log as artifacts.

Open the repo's **Actions** tab ▸ latest **iOS Simulator** run ▸ **Artifacts**.
You can also start a run by hand from **Actions ▸ iOS Simulator ▸ Run workflow**
and choose a different device type.

### 2b. Interact with it in the browser

[Appetize.io](https://appetize.io) runs real iOS simulators in the browser and
offers an **iPhone 13 Pro** device (iOS 15.5 – 18.2 at the time of writing).
Its free tier is a small monthly allowance, enough for trying the keyboard.

Manual way (no CI secrets needed):

1. Download `MongolKey-iOS-Simulator-app` from the latest Actions run and unzip
   it — you get `MongolKey.app.zip`.
2. Go to <https://appetize.io/upload>, upload `MongolKey.app.zip` (platform iOS).
3. On the app page choose **iPhone 13 Pro** as the device, or append
   `?device=iphone13pro&osVersion=18.2` to the app URL.
4. In the session: Settings ▸ General ▸ Keyboard ▸ Keyboards ▸ Add New Keyboard… ▸
   MongolKey, then open MongolKey ▸ Try It and hold 🌐 to switch.

Automatic way: create an Appetize API token (Account ▸ API token) and add it as
the repository secret `APPETIZE_API_TOKEN`. The workflow then uploads every
build and prints a ready **"Open MongolKey on a virtual iPhone 13 Pro"** link in
the run summary. To keep one stable link instead of a new app per run, also add
the repository *variable* `APPETIZE_PUBLIC_KEY` with the public key of the app
Appetize created the first time.

Alternatives if you need a full macOS desktop instead: a rented cloud Mac such as
MacinCloud or MacStadium, then follow section 1 there.

---

## 3. Reading the screenshots

Artifact `screenshots-iPhone 13 Pro-macos-26` contains, under `pass1/`:

- `app-01-setup` … `app-05-romanizer-typing` — the four tabs, then the live
  romanizer being typed into with the system keyboard.
- `keyboard-*-settings-*` — the Settings flow that enables MongolKey.
- `keyboard-*-keyboard-picker` — the 🌐 input switcher listing MongolKey.
- `keyboard-*-switched-to-mongolkey`, `composing-mongol`, `committed-mongol`,
  `composing-aavdaa`, `composing-nohoy`, `composing-sain`, `typed-all-words`,
  `predictions`, `prediction-tapped`, `numbers-layer`, `final` — the
  extension itself: the candidate bar with vertical candidates (including
  the informal spelling `nohoy` finding нохой), the committed words in the
  field, the next-word predictions offered after `sain` and the result of
  tapping one, the number layer.
- `zz-simulator-final` — a raw capture of the simulator after the tests.

The run's log also contains downscaled copies of the key screenshots as
base64 (between `@@IMG` / `@@END` markers) so they can be inspected without
downloading the artifact.

The test asserts that the tester field ends up containing Mongolian-script
characters, so a red `test2_KeyboardExtension` means the keyboard really did
not produce output. If a `settings-missing-*` screenshot appears, iOS moved
something in Settings and `UITests/MongolKeyUITests.swift` ▸
`enableKeyboardFromGeneral()` needs its row names updated.

Things learned the hard way, all handled by the test now: iOS 26 moved the
globe key out of the keyboard into the bar below it; the input switcher is a
press-and-slide menu (a plain tap on a row does not always select it); iOS
shows a one-time QuickPath tip with a Continue button over the first system
keyboard; and a fully unsigned build (`CODE_SIGNING_ALLOWED=NO`) must be
avoided in favour of ad-hoc signing (`CODE_SIGN_IDENTITY=-`).

## 4. What the automated run does not cover

- Real touch latency and haptics — only a physical device shows those.
- Third-party host apps (Notes, Messages): the UI test types into MongolKey's
  own Try It field. In an interactive session (Mac or Appetize) open Notes and
  switch keyboards with 🌐 to check that.
