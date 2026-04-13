FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    gnupg \
    git \
    python3 \
    xvfb \
    x11vnc \
    tor \
    netcat-openbsd \
    fonts-liberation \
    libnss3 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm -f google-chrome-stable_current_amd64.deb \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/novnc/noVNC.git /noVNC \
    && git clone --depth 1 https://github.com/novnc/websockify.git /noVNC/utils/websockify

COPY torrc /etc/tor/torrc
COPY start.sh /usr/local/bin/start.sh

RUN chmod +x /usr/local/bin/start.sh

RUN cat > /noVNC/index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Tor Browser on Render</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;700&family=Source+Serif+4:opsz,wght@8..60,300;8..60,400&display=swap" rel="stylesheet" />
  <style>
    :root { --background: hsl(0 0% 5.1%); --card: hsl(0 0% 7%); --border: hsl(0 0% 16%); --foreground: hsl(0 0% 90%); --muted: hsl(0 0% 50%); --font-heading: 'Space Grotesk', sans-serif; --font-body: 'Source Serif 4', serif; }
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; background: radial-gradient(circle at 15% 10%, hsl(0 0% 9%), transparent 45%), var(--background); color: var(--foreground); font-family: var(--font-body); display: grid; place-items: center; padding: 2rem 1rem; }
    .container { width: 100%; max-width: 42rem; padding-top: 6rem; padding-bottom: 6rem; animation: fade-up 0.45s ease-out both; }
    .zone { border: 2px dashed var(--border); background: var(--card); padding: 2.5rem; }
    .label { margin: 0 0 0.75rem; font-family: var(--font-heading); font-size: 10px; letter-spacing: 0.2em; text-transform: uppercase; color: var(--muted); }
    h1 { margin: 0; font-family: var(--font-heading); font-size: clamp(1.75rem, 3.2vw, 2.5rem); font-weight: 700; line-height: 1.1; }
    p { margin: 0.9rem 0 2rem; color: var(--muted); font-size: 1.05rem; line-height: 1.6; }
    .actions { border: 1px solid var(--border); padding: 1rem; animation: fade-up 0.45s ease-out 0.08s both; }
    .open-btn { display: inline-block; text-decoration: none; background: var(--foreground); color: var(--background); border: 1px solid var(--foreground); padding: 0.75rem 1.25rem; font-family: var(--font-heading); font-size: 0.75rem; letter-spacing: 0.08em; text-transform: uppercase; transition: all 140ms ease; }
    .open-btn:hover { background: transparent; color: var(--foreground); border-color: hsl(0 0% 28%); }
    .pulse-line { margin-top: 1.1rem; height: 1px; width: 100%; background: var(--border); overflow: hidden; position: relative; }
    .pulse-line::after { content: ""; position: absolute; left: -30%; top: 0; height: 1px; width: 30%; background: var(--foreground); animation: pulse-line 1.4s linear infinite; opacity: 0.7; }
    @keyframes fade-up { from { opacity: 0; transform: translateY(16px); } to { opacity: 1; transform: translateY(0); } }
    @keyframes pulse-line { from { transform: translateX(0); } to { transform: translateX(450%); } }
    @media (max-width: 640px) { .zone { padding: 1.5rem; } .actions { padding: 0.85rem; } p { font-size: 0.98rem; } }
  </style>
</head>
<body>
  <main class="container">
    <section class="zone">
      <p class="label">Tor Browser Service</p>
      <h1>Single-session Chrome over Tor</h1>
      <p>This Render service runs one Chrome session in-container, routes traffic through Tor, and exposes the desktop with noVNC.</p>
      <div class="actions">
        <a class="open-btn" href="/vnc.html?autoconnect=true&resize=scale" target="_self">Open browser</a>
        <div class="pulse-line" aria-hidden="true"></div>
      </div>
    </section>
  </main>
</body>
</html>
HTML

EXPOSE 6080

CMD ["/usr/local/bin/start.sh"]