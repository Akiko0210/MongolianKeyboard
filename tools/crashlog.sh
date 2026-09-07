#!/usr/bin/env bash
# Print the newest simulator crash report for MongolKey (app) or MongolKeyboard
# (keyboard extension): exception, termination reason and the crashed thread's
# top frames — what to paste when "it keeps crashing".
#
#   tools/crashlog.sh            # newest report of either process
#   tools/crashlog.sh --all      # list every report found
set -euo pipefail

dir="$HOME/Library/Logs/DiagnosticReports"
[[ -d "$dir" ]] || { echo "no crash reports directory at $dir"; exit 1; }

# .ips is the modern format (JSON header line + JSON body); .crash is legacy text.
mapfile -t reports < <(ls -t "$dir"/MongolKey*.ips "$dir"/MongolKey*.crash 2>/dev/null || true)
if [[ ${#reports[@]} -eq 0 ]]; then
  echo "no MongolKey / MongolKeyboard crash reports in $dir"
  echo "(if the keyboard vanishes but no report appears, it was probably killed for memory — see docs/TESTING.md)"
  exit 0
fi

if [[ "${1:-}" == "--all" ]]; then
  printf '%s\n' "${reports[@]}"
  exit 0
fi

report="${reports[0]}"
echo "Newest report: $report"
echo

case "$report" in
  *.ips)
    python3 - "$report" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8", errors="replace") as f:
    lines = f.read().split("\n", 1)
header = json.loads(lines[0])
try:
    body = json.loads(lines[1])
except Exception as e:
    print("could not parse body:", e); print(lines[1][:3000]); sys.exit(0)
print("process:   ", body.get("procName"), "| bundle:", header.get("bundleID"), "| OS:", header.get("os_version"))
print("timestamp: ", header.get("timestamp"))
exc = body.get("exception", {})
print("exception: ", exc.get("type"), exc.get("signal"), exc.get("codes"))
term = body.get("termination", {})
if term:
    print("terminated:", term.get("namespace"), term.get("indicator"), term.get("reasons"))
if body.get("asi"):
    print("app info:  ", body["asi"])
faulting = body.get("faultingThread", 0)
threads = body.get("threads", [])
images = body.get("usedImages", [])
if threads and faulting < len(threads):
    t = threads[faulting]
    print(f"\ncrashed thread {faulting}: {t.get('name') or t.get('queue') or ''}")
    for i, fr in enumerate(t.get("frames", [])[:25]):
        img = images[fr.get("imageIndex", -1)] if 0 <= fr.get("imageIndex", -1) < len(images) else {}
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
