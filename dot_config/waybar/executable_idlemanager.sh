#!/usr/bin/env bash

if pgrep -x "hypridle" >/dev/null; then
  echo "{\"text\": \"󰒲 on \", \"tooltip\": \"Idle Management on\", \"class\": \"on\"}"
else
  echo "{\"text\": \"󰒳 off\", \"tooltip\": \"Idle Management off\", \"class\": \"off\"}"
fi
