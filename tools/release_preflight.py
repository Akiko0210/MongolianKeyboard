#!/usr/bin/env python3
"""Inspect built app/extension metadata. Local success is not review approval."""
import argparse
import plistlib
import re
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--submission", action="store_true")
    args = parser.parse_args()
    errors = []

    def check(condition, message):
        if not condition:
            errors.append(message)

    def plist(path):
        try:
            with path.open("rb") as stream:
                return plistlib.load(stream)
        except (OSError, plistlib.InvalidFileException) as error:
            errors.append(f"Cannot read {path}: {error}")
            return {}

    app = args.app
    extension = app / "PlugIns/MongolKeyboard.appex"
    app_info = plist(app / "Info.plist")
    extension_info = plist(extension / "Info.plist")
    for bundle in [app, extension]:
        privacy = plist(bundle / "PrivacyInfo.xcprivacy")
        check(privacy.get("NSPrivacyTracking") is False, f"{bundle.name}: tracking declaration")
        check(privacy.get("NSPrivacyCollectedDataTypes") == [], f"{bundle.name}: data collection declaration")
        declarations = privacy.get("NSPrivacyAccessedAPITypes", [])
        check(any(d.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryUserDefaults"
                  and "CA92.1" in d.get("NSPrivacyAccessedAPITypeReasons", []) for d in declarations),
              f"{bundle.name}: missing private-preferences API reason")
        for resource in ["NotoSansMongolian-Regular.ttf", "ClassicalMongolianDashitseden.ttf", "OFL.txt", "LICENSES.md"]:
            check((bundle / resource).is_file(), f"{bundle.name}: missing {resource}")
        for resource in ["lexicon.tsv", "bigrams.tsv", "orthography.tsv", "DATA_SOURCES.txt"]:
            check(any(bundle.glob(f"*.bundle/{resource}")), f"{bundle.name}: missing {resource}")

    extension_spec = extension_info.get("NSExtension", {})
    attributes = extension_spec.get("NSExtensionAttributes", {})
    check(extension_spec.get("NSExtensionPointIdentifier") == "com.apple.keyboard-service", "Wrong extension point")
    check(attributes.get("RequestsOpenAccess") is False, "Keyboard requests Full Access")
    check(attributes.get("IsASCIICapable") is False, "Mongolian composer must not advertise ASCII typing")
    check(attributes.get("PrimaryLanguage") == "mn", "Wrong keyboard language")
    check((app / "ORTHOGRAPHY.md").is_file(), "Missing offline spelling guide")
    for key in ["CFBundleVersion", "CFBundleShortVersionString"]:
        check(bool(app_info.get(key)) and app_info.get(key) == extension_info.get(key), f"Mismatched {key}")
    check(len(app_info.get("UISupportedInterfaceOrientations~ipad", [])) == 4, "Missing iPad orientations")

    if args.submission:
        sdk = app_info.get("DTSDKName", "")
        version = re.fullmatch(r"iphoneos(\d+)(?:\.\d+)*", sdk)
        check(version is not None and int(version[1]) >= 26, f"Submission requires iPhoneOS SDK 26+, found {sdk!r}")
        # The generator records which data the bundle was built from
        # (tools/licence_clean.py). Only the licence-clean build carries data
        # with an explicit redistribution grant for every source.
        for bundle in [app, extension]:
            builds = {line.split(":", 1)[1].strip()
                      for path in bundle.glob("*.bundle/DATA_SOURCES.txt")
                      for line in path.read_text(encoding="utf-8").splitlines()
                      if line.startswith("build:")}
            check(builds == {"licence-clean"},
                  f"{bundle.name}: language data is not the licence-clean build "
                  f"(found {sorted(builds) or 'no DATA_SOURCES.txt'}); legacy data includes "
                  "tugstugi/mongolian-nlp, which has no licence. See docs/DATA_PROVENANCE.md.")

    if errors:
        for error in errors:
            print("FAIL:", error)
        return 1
    print("PASS: built app and keyboard metadata/resources. Submission rights, signing, physical devices and App Review remain separate checks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
