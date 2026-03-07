#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <command> [args...]"
  exit 1
fi

cmd="$1"

# Find PIDs of matching processes, excluding this script itself
pids=$(pgrep -f "$cmd" | grep -v "^$$\$" || true)

if [[ -n "$pids" ]]; then
  echo "Process '$cmd' is running (PID(s): $pids). Killing..."
  kill $pids
  echo "Killed."
else
  echo "Process '$cmd' is not running. Starting..."
  "$@" &
  echo "Started with PID $!"
fi
