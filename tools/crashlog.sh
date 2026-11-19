#!/usr/bin/env bash
# Print the newest simulator crash report for MongolKey (app) or MongolKeyboard
# (keyboard extension): exception, termination reason, the fatal-error message
# if any, and the crashed thread's top frames — what to paste when "it crashes".
#
#   tools/crashlog.sh                 # newest report of either process
#   tools/crashlog.sh --since EPOCH   # only a report written after that time
#   tools/crashlog.sh --all           # list every report found
#
# Works with macOS's stock bash 3.2 (no mapfile, no associative arrays).
set -euo pipefail

dir="$HOME/Library/Logs/DiagnosticReports"
mode="newest"
since=0
case "${1:-}" in
  --all) mode="all" ;;
  --since) since="${2:-0}" ;;
esac

if [[ ! -d "$dir" ]]; then
  echo "no crash reports directory at $dir"
  exit 1
fi

# Newest first. .ips is the modern format (JSON header line + JSON body);
# .crash is the legacy text format.
reports="$(ls -t "$dir"/MongolKey*.ips "$dir"/MongolKey*.crash 2>/dev/null || true)"
if [[ -z "$reports" ]]; then
  echo "no MongolKey / MongolKeyboard crash reports in $dir"
  echo "(a keyboard that vanishes without a report was killed by iOS for memory — see README ▸ Troubleshooting)"
  exit 0
fi

if [[ "$mode" == "all" ]]; then
  printf '%s\n' "$reports"
  exit 0
fi

report="$(printf '%s\n' "$reports" | head -n 1)"
if [[ "$since" != 0 ]]; then
  modified="$(stat -f %m "$report" 2>/dev/null || echo 0)"
  if [[ "$modified" -lt "$since" ]]; then
    echo "no crash report newer than the launch (newest is $report)."
    echo "If the app is gone anyway, iOS may have killed it without a report; run: xcrun simctl spawn booted log show --last 2m --predicate 'process == \"MongolKey\"'"
    exit 0
  fi
fi

echo "Newest report: $report"
echo

case "$report" in
  *.ips)
    python3 - "$report" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8", errors="replace") as f:
    parts = f.read().split("\n", 1)
header = json.loads(parts[0])
try:
    body = json.loads(parts[1])
except Exception as e:
    print("could not parse body:", e); print(parts[1][:3000]); sys.exit(0)
print("process:   ", body.get("procName"), "| bundle:", header.get("bundleID"), "| OS:", header.get("os_version"))
print("timestamp: ", header.get("timestamp"))
exc = body.get("exception", {})
print("exception: ", exc.get("type"), exc.get("signal"), exc.get("codes"))
term = body.get("termination", {})
if term:
    print("terminated:", term.get("namespace"), term.get("indicator"), term.get("reasons"))
if body.get("asi"):
    print("message:   ", body["asi"])
faulting = body.get("faultingThread", 0)
threads = body.get("threads", [])
images = body.get("usedImages", [])
if threads and faulting < len(threads):
    t = threads[faulting]
    print(f"\ncrashed thread {faulting}: {t.get('name') or t.get('queue') or ''}")
    for i, fr in enumerate(t.get("frames", [])[:25]):
        idx = fr.get("imageIndex", -1)
        img = images[idx] if 0 <= idx < len(images) else {}
        name = img.get("name", "?")
        sym = fr.get("symbol", "")
        off = fr.get("symbolLocation", fr.get("imageOffset", 0))
        src = f" ({fr['sourceFile']}:{fr.get('sourceLine','')})" if fr.get("sourceFile") else ""
        print(f"  {i:2d}  {name:32s} {sym} + {off}{src}")
PY
    ;;
  *)
    sed -n '1,80p' "$report"
    ;;
esac
