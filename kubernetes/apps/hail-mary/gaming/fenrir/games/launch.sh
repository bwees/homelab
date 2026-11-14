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

# GoW's launcher only sets gamescope's output size, so games render at
# gamescope's 1280x720 default. Shadow gamescope to add the render size.
GAMESCOPE_SHIM_DIR=/tmp/fenrir-bin
if real_gamescope="$(command -v gamescope)"; then
  mkdir -p "$GAMESCOPE_SHIM_DIR"
  cat > "$GAMESCOPE_SHIM_DIR/gamescope" <<EOF
#!/bin/bash
exec "$real_gamescope" -w "\${GAMESCOPE_WIDTH}" -h "\${GAMESCOPE_HEIGHT}" "\$@"
EOF
  chmod 755 "$GAMESCOPE_SHIM_DIR/gamescope"
  export PATH="$GAMESCOPE_SHIM_DIR:$PATH"
fi

exec /entrypoint.sh
