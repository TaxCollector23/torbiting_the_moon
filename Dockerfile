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
COPY public/index.html /noVNC/index.html

RUN chmod +x /usr/local/bin/start.sh

EXPOSE 6080

CMD ["/usr/local/bin/start.sh"]