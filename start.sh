#!/bin/bash

URL="${URL:-https://check.torproject.org}"

# Start Tor
tor -f /etc/tor/torrc &

# Wait for Tor
echo "Waiting for Tor..."
for i in $(seq 1 30); do
    nc -z 127.0.0.1 9050 2>/dev/null && echo "Tor ready." && break
    sleep 1
done

# Start virtual display
Xvfb :99 -screen 0 1280x800x24 -ac &
sleep 2

# Start VNC
x11vnc -display :99 -forever -nopw -rfbport 5900 -shared -quiet &
sleep 1

# Start noVNC
/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 6080 &
sleep 1

# Launch Google Chrome through Tor
DISPLAY=:99 google-chrome \
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

wait
