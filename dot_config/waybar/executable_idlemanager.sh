#!/usr/bin/env bash

if pgrep -x "hypridle" >/dev/null; then
  echo "{\"text\": \"󰒲\", \"tooltip\": \"Idle Management on\", \"class\": \"on\"}"
else
  echo "{\"text\": \"󰒳\", \"tooltip\": \"Idle Management off\", \"class\": \"off\"}"
fi
