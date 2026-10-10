#!/usr/bin/env bash
# Runs a command; if it fails, publishes the important log lines as a GitHub
# annotation so errors are visible on the run page without opening raw logs.
# Usage: tool/ci_run.sh "<title>" <command...>
title="$1"
shift
log="$(mktemp)"
"$@" 2>&1 | tee "$log"
code=${PIPESTATUS[0]}
if [ "$code" -ne 0 ]; then
  {
    grep -E "error|Error|ERROR|What went wrong|Exception|FAILED|Could not|> " "$log" | grep -v "^\s*$" | head -n 60
    echo "----- last lines -----"
    tail -n 40 "$log"
  } > "$log.err"
  msg="$(sed -e 's/%/%25/g' "$log.err" | awk '{printf "%s%%0A", $0}')"
  echo "::error title=$title::$msg"
fi
exit "$code"
