#!/usr/bin/env bash

if pgrep -x "hyprsunset" >/dev/null; then
  echo "{\"text\": \"󱩌 on \", \"tooltip\": \"Nightlight on\", \"class\": \"on\"}"
else
  echo "{\"text\": \"󱩍 off\", \"tooltip\": \"Nightlight off\", \"class\": \"off\"}"
fi
