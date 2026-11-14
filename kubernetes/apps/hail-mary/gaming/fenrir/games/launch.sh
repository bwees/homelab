#!/bin/bash
set -euo pipefail

until [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do
  echo "fenrir: waiting for wayland display" >&2
  sleep 1
done

until [ -S "$XDG_RUNTIME_DIR/pulse-socket" ]; do
  echo "fenrir: waiting for pulse socket" >&2
  sleep 1
done

if command -v pactl >/dev/null; then
  PULSE_SINK="$(pactl list sinks short | awk '$2 ~ /^virtual_sink/ {print $2; exit}')"
  export PULSE_SINK
  export PULSE_SOURCE="${PULSE_SINK}.monitor"
fi

exec /entrypoint.sh
