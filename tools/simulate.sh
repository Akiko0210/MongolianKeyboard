#!/usr/bin/env bash
#
# simulate.sh — build MongolKey and run it on an iPhone 13 Pro-sized simulator
# with one command (macOS + Xcode only; see docs/TESTING.md for other OSes).
#
#   tools/simulate.sh                      # generate, build, boot iPhone 13 Pro, install, launch
#   tools/simulate.sh --device "iPhone 17" # any device type from `xcrun simctl list devicetypes`
#   tools/simulate.sh --build-only --universal   # CI: arm64+x86_64 .app for Appetize.io
#   tools/simulate.sh --prepare-sim        # CI: create+boot the simulator, print its UDID
#
set -euo pipefail

DEVICE_NAME="${DEVICE_NAME:-iPhone 13 Pro}"
# If the exact device type is missing from this Xcode, fall back to models with
# the same 390×844 pt / @3x screen first, then to whatever is available.
FALLBACK_DEVICES=("iPhone 13 Pro" "iPhone 14" "iPhone 13" "iPhone 16e" "iPhone 17")
UNIVERSAL=0
BUILD_ONLY=0
PREPARE_SIM_ONLY=0
OPEN_SIMULATOR=1
SKIP_GENERATE=0
CONFIGURATION=Debug

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)        DEVICE_NAME="$2"; shift 2 ;;
    --universal)     UNIVERSAL=1; shift ;;
    --build-only)    BUILD_ONLY=1; shift ;;
    --prepare-sim)   PREPARE_SIM_ONLY=1; shift ;;
    --no-open)       OPEN_SIMULATOR=0; shift ;;
    --skip-generate) SKIP_GENERATE=1; shift ;;
    -h|--help)       sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")/.."
ROOT="$PWD"
DERIVED="$ROOT/build/DerivedData"
BUNDLE_ID="com.mongolkey.app"

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found. $2" >&2; exit 1; }; }
need xcrun   "Install Xcode from the App Store, then run: sudo xcode-select -s /Applications/Xcode.app"
if ! xcode-select -p 2>/dev/null | grep -q "Xcode.*\.app"; then
  echo "error: the active developer directory is not a full Xcode install ($(xcode-select -p 2>/dev/null))." >&2
  echo "       Install Xcode from the App Store, then: sudo xcode-select -s /Applications/Xcode.app" >&2
  exit 1
fi
need python3 "python3 ships with the Xcode Command Line Tools."

# ---------------------------------------------------------------- simulator --
latest_ios_runtime() {
  xcrun simctl list runtimes -j | python3 -c '
import json, sys
rs = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS" and r["isAvailable"]]
rs.sort(key=lambda r: [int(x) for x in r["version"].split(".")])
print(rs[-1]["identifier"] if rs else "")'
}

# Prints the device-type identifier for NAME if it exists and the runtime supports it.
device_type_for() {
  local name="$1" runtime="$2"
  xcrun simctl list -j | python3 -c '
import json, sys
name, runtime = sys.argv[1], sys.argv[2]
data = json.load(sys.stdin)
types = {t["name"]: t["identifier"] for t in data["devicetypes"]}
rt = next((r for r in data["runtimes"] if r["identifier"] == runtime), None)
supported = {t["identifier"] for t in (rt or {}).get("supportedDeviceTypes", [])}
ident = types.get(name)
print(ident if ident and (not supported or ident in supported) else "")' "$name" "$runtime"
}

existing_device_udid() {
  local name="$1" runtime="$2"
  xcrun simctl list devices -j | python3 -c '
import json, sys
name, runtime = sys.argv[1], sys.argv[2]
for d in json.load(sys.stdin)["devices"].get(runtime, []):
    if d["name"] == name and d.get("isAvailable", True):
        print(d["udid"]); break' "$name" "$runtime"
}

prepare_simulator() {
  local runtime; runtime="$(latest_ios_runtime)"
  [[ -n "$runtime" ]] || { echo "error: no iOS simulator runtime installed (Xcode ▸ Settings ▸ Components)" >&2; exit 1; }

  local chosen="" devtype=""
  for candidate in "$DEVICE_NAME" "${FALLBACK_DEVICES[@]}"; do
    devtype="$(device_type_for "$candidate" "$runtime")"
    if [[ -n "$devtype" ]]; then chosen="$candidate"; break; fi
  done
  if [[ -z "$chosen" ]]; then
    echo "error: none of '$DEVICE_NAME' / ${FALLBACK_DEVICES[*]} exist in this Xcode. Available:" >&2
    xcrun simctl list devicetypes | grep iPhone >&2
    exit 1
  fi
  [[ "$chosen" == "$DEVICE_NAME" ]] || echo "note: '$DEVICE_NAME' not available in this Xcode; using '$chosen' instead" >&2

  local sim_name="MongolKey $chosen"
  SIM_UDID="$(existing_device_udid "$sim_name" "$runtime")"
  if [[ -z "$SIM_UDID" ]]; then
    SIM_UDID="$(xcrun simctl create "$sim_name" "$devtype" "$runtime")"
  fi
  SIM_DEVICE_NAME="$chosen"
  SIM_RUNTIME="$runtime"
  echo "simulator: $sim_name ($SIM_UDID) on ${runtime##*.}" >&2

  xcrun simctl boot "$SIM_UDID" 2>/dev/null || true   # "already booted" is fine
  xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null
}

if [[ "$PREPARE_SIM_ONLY" == 1 ]]; then
  prepare_simulator
  echo "$SIM_UDID"
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    { echo "SIM_UDID=$SIM_UDID"; echo "SIM_DEVICE_NAME=$SIM_DEVICE_NAME"; echo "SIM_RUNTIME=$SIM_RUNTIME"; } >> "$GITHUB_ENV"
  fi
  exit 0
fi

# -------------------------------------------------------------------- build --
if [[ "$SKIP_GENERATE" == 0 ]]; then
  if ! command -v xcodegen >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      echo "xcodegen not found — installing with Homebrew…" >&2
      brew install xcodegen
    else
      need xcodegen "Install Homebrew (https://brew.sh), then: brew install xcodegen"
    fi
  fi
  xcodegen generate
fi

# Ad-hoc sign (identity "-") rather than CODE_SIGNING_ALLOWED=NO: an app
# extension that is not signed at all is listed by Settings but never offered
# as a keyboard, so the 🌐 key never shows MongolKey.
SIGN_FLAGS=(CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES)
# macOS ships bash 3.2, where an empty array counts as unset under `set -u`;
# the ${arr[@]+"${arr[@]}"} form below expands safely either way.
ARCH_FLAGS=()
if [[ "$UNIVERSAL" == 1 ]]; then
  ARCH_FLAGS=(ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO)
fi

echo "building MongolKey (+ keyboard extension) for the simulator…" >&2
mkdir -p "$ROOT/build"
BUILD_LOG="$ROOT/build/xcodebuild.log"
if ! xcodebuild -project MongolKey.xcodeproj -scheme MongolKey \
  -sdk iphonesimulator -destination "generic/platform=iOS Simulator" \
  -configuration "$CONFIGURATION" -derivedDataPath "$DERIVED" \
  "${SIGN_FLAGS[@]}" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} build >"$BUILD_LOG" 2>&1; then
  echo "error: xcodebuild failed — full log: $BUILD_LOG" >&2
  grep -E "error:|\*\* BUILD" "$BUILD_LOG" | sort -u | head -n 40 >&2
  exit 65
fi
grep -E "\*\* BUILD" "$BUILD_LOG" >&2 || true

APP="$DERIVED/Build/Products/$CONFIGURATION-iphonesimulator/MongolKey.app"
[[ -d "$APP" ]] || { echo "error: build product not found at $APP" >&2; exit 1; }
echo "app: $APP" >&2
if [[ -n "${GITHUB_ENV:-}" ]]; then echo "APP_PATH=$APP" >> "$GITHUB_ENV"; fi

[[ "$BUILD_ONLY" == 1 ]] && exit 0

# ------------------------------------------------------------- install+run --
prepare_simulator
xcrun simctl install "$SIM_UDID" "$APP"
[[ "$OPEN_SIMULATOR" == 1 ]] && open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" >/dev/null
# A launch crash shows up as the app vanishing right away: check it is still
# running a few seconds later, and point at the crash report if not.
sleep 4
if ! xcrun simctl spawn "$SIM_UDID" launchctl list 2>/dev/null | grep -q "$BUNDLE_ID"; then
  echo "warning: $BUNDLE_ID is not running 4 s after launch — it probably crashed." >&2
  echo "         Run tools/crashlog.sh to see the crash report." >&2
fi

cat >&2 <<MSG

MongolKey is running on "$SIM_DEVICE_NAME".
Enable the keyboard once per install (cannot be scripted):
  Settings ▸ General ▸ Keyboard ▸ Keyboards ▸ Add New Keyboard… ▸ MongolKey
then in the app's Try It tab hold 🌐 and pick MongolKey.
MSG
