#!/bin/sh
pkill -x polybar 2>/dev/null
while pgrep -x polybar >/dev/null; do sleep 0.1; done

if command -v xrandr >/dev/null 2>&1; then
  for m in $(polybar --list-monitors | cut -d: -f1); do
    MONITOR=$m polybar main --config="$HOME/.config/polybar/config.ini" &
  done
else
  polybar main --config="$HOME/.config/polybar/config.ini" &
fi
