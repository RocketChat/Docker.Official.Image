FROM phusion/baseimage:noble-1.0.2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Core runtime environment (matches official image expectations)
# ------------------------------------------------------------
ENV NODE_ENV=production \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    MONGO_URL=mongodb://127.0.0.1:27017/rocketchat \
    MONGO_OPLOG_URL=mongodb://127.0.0.1:27017/local \
    HOME=/app \
    METEOR_DISABLE_OPTIMISTIC_CACHING=1

# ------------------------------------------------------------
# Base packages
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    python3 \
    make \
    g++ \
    netcat-openbsd \
    gosu \
    tini \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Node.js 20 LTS (HARD PIN — supported)
# ------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs=20.* && \
    node -v && npm -v && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# MongoDB Community Edition 7.0
# noble workaround: use jammy repo
# ------------------------------------------------------------
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
      gpg --dearmor -o /etc/apt/keyrings/mongodb-server-7.0.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/mongodb-server-7.0.gpg] \
      https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" \
      > /etc/apt/sources.list.d/mongodb-org-7.0.list && \
    apt-get update && \
    apt-get install -y mongodb-org && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Rocket.Chat official prebuilt bundle
# ------------------------------------------------------------
WORKDIR /app

RUN curl -fsSL https://releases.rocket.chat/latest/download \
    -o rocket.chat.tgz && \
    tar -xzf rocket.chat.tgz && \
    rm rocket.chat.tgz

# ------------------------------------------------------------
# Server dependencies (production only)
# ------------------------------------------------------------
WORKDIR /app/bundle/programs/server
RUN npm install --omit=dev --no-audit --no-fund

# ------------------------------------------------------------
# Runtime user & filesystem (official layout compatible)
# ------------------------------------------------------------
RUN useradd -r -u 999 -g nogroup -d /app rocketchat && \
    mkdir -p \
      /app/uploads \
      /var/lib/mongodb \
      /var/log/mongodb \
      /tmp/meteor && \
    chown -R rocketchat:nogroup \
      /app \
      /var/lib/mongodb \
      /var/log/mongodb \
      /tmp/meteor

VOLUME ["/app/uploads", "/var/lib/mongodb"]

# ------------------------------------------------------------
# Entrypoint
# ------------------------------------------------------------
COPY rc-aio-entrypoint.sh /usr/local/bin/rc-aio-entrypoint.sh
RUN chmod +x /usr/local/bin/rc-aio-entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/rc-aio-entrypoint.sh"]
