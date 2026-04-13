#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-6080}"
URL="${URL:-https://check.torproject.org}"
DISPLAY="${DISPLAY:-:99}"

cleanup() {
  local code=$?
  pkill -P $$ || true
  exit "$code"
}
trap cleanup EXIT INT TERM

echo "Starting Tor..."
tor -f /etc/tor/torrc &

echo "Waiting for Tor SOCKS listener on 127.0.0.1:9050..."
for _ in $(seq 1 60); do
  if nc -z 127.0.0.1 9050 >/dev/null 2>&1; then
    echo "Tor is ready."
    break
  fi
  sleep 1
done

if ! nc -z 127.0.0.1 9050 >/dev/null 2>&1; then
  echo "Tor failed to start in time."
  exit 1
fi

echo "Starting Xvfb on ${DISPLAY}..."
Xvfb "$DISPLAY" -screen 0 1280x800x24 -ac &

sleep 1

echo "Starting x11vnc on :5900..."
x11vnc -display "$DISPLAY" -forever -shared -rfbport 5900 -nopw -xkb -quiet &

sleep 1

echo "Starting noVNC on 0.0.0.0:${PORT}..."
/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen "0.0.0.0:${PORT}" &

sleep 1

echo "Launching Chrome through Tor proxy..."
DISPLAY="$DISPLAY" google-chrome \
  --no-sandbox \
  --disable-gpu \
  --disable-software-rasterizer \
  --disable-dev-shm-usage \
  --proxy-server="socks5://127.0.0.1:9050" \
  --no-first-run \
  --disable-infobars \
  --disable-extensions \
  --window-size=1280,800 \
  --window-position=0,0 \
  "$URL" &

wait -n