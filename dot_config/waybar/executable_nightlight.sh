#!/usr/bin/env bash

if pgrep -x "hyprsunset" >/dev/null; then
  echo "{\"text\": \"󱩌\", \"tooltip\": \"Nightlight on\", \"class\": \"on\"}"
else
  echo "{\"text\": \"󱩍\", \"tooltip\": \"Nightlight off\", \"class\": \"off\"}"
fi
