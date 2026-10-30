# Testing MongolKey

For the completed local audit and its limits, see [AUDIT.md](AUDIT.md).
Use a dedicated simulator: another UI automation session on the same device can
switch apps and invalidate results. Simulator tests cannot establish support in
Instagram, WhatsApp or other physical-device apps; use [COMPATIBILITY.md](COMPATIBILITY.md).

## Local checks

Xcode, an installed iOS Simulator runtime and XcodeGen are required. Xcode 16 can
run local development checks; submission requires the newer toolchain described
in [RELEASE.md](RELEASE.md).

```sh
swift test --package-path Packages/MongolEngine
xcodegen generate
xcrun simctl list devices available
xcodebuild test -project MongolKey.xcodeproj -scheme MongolKey \
  -destination 'platform=iOS Simulator,id=YOUR_DEDICATED_SIMULATOR_UUID' \
  -derivedDataPath build/Audit -parallel-testing-enabled NO \
  -resultBundlePath build/LocalTests.xcresult CODE_SIGN_IDENTITY=-
python3 tools/release_preflight.py --app build/Audit/Build/Products/Debug-iphonesimulator/MongolKey.app
swift tools/ShapeProbe.swift Shared/Fonts build/shape-probe
```

Use a new result-bundle path for each run. The scheme includes engine tests,
native rendering/layout tests and UI tests. `-only-testing:MongolEngineTests`
or `-only-testing:MongolKeyUITests` narrows a justified rerun.

The UI suite enables the extension through Settings, checks the container tabs,
then types through the actual extension. It asserts stored spellings and their
Unicode separators, predictions, both font selections, Cyrillic үг, numbers,
unknown-input preservation, deletion, Return and landscape typing. It identifies
the extension by its own accessibility identifiers, not ordinary QWERTY keys.
Settings UI changes can still break automation; inspect the failed action and
screenshots before attributing a failure to conversion.

Screenshots are attached to the result bundle. Export them with:

```sh
xcrun xcresulttool export attachments --path build/LocalTests.xcresult \
  --output-path build/screenshots
```

For interactive use, `tools/simulate.sh` builds and launches the app. Enable
MongolKey under Settings → General → Keyboard → Keyboards → Add New Keyboard.
Open Try It, focus the keyboard tester, hold the system globe and select MongolKey.
If no onscreen keyboard appears, turn off Simulator → I/O → Keyboard → Connect
Hardware Keyboard. A/Б switches alphabets; Dashitseden and Noto Sans select the
preview face. No Full Access is required.

## CI

[The workflow](../.github/workflows/ios-simulator.yml) is configured for macos-26
and macos-15 runners. It builds a simulator app, checks packaged resources, runs
engine/native/UI tests and uploads result bundles and screenshots. This local
audit did not run or certify the remote matrix. Test failures propagate through
the logging pipeline and cause the final job status to fail.

An optional Appetize upload is configured when the repository has the relevant
credentials. Its device availability, service limits and compatibility must be
checked with that provider; they are not established by local tests.

## Coverage boundaries

Automated examples prove those cases under the tested conditions. They do not
validate every dictionary entry, irregular form or sentence. The independently
sourced spelling set currently contains 16 examples. Expand it with documented
government/education references, keeping generated output separate from ground
truth. Physical-device checks still include third-party hosts, VoiceOver,
low-memory restarts, iPad floating mode and all supported OS versions.
