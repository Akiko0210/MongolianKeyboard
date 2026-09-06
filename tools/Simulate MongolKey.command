#!/usr/bin/env bash
# Double-click this file in Finder to build MongolKey and open it in an
# iPhone 13 Pro simulator. It just runs tools/simulate.sh in a Terminal window.
cd "$(dirname "$0")/.." || exit 1
tools/simulate.sh "$@"
status=$?
echo
if [ $status -eq 0 ]; then
  echo "Done — the simulator window should be open. You can close this Terminal window."
else
  echo "Something failed (exit $status). Scroll up for the error; the full build log is build/xcodebuild.log."
fi
read -r -p "Press Return to close… " _
