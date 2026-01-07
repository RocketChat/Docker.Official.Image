FROM phusion/baseimage:noble-1.0.2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Versions
# ------------------------------------------------------------
ENV DENO_VERSION=1.43.5
ENV NATS_VERSION=2.11.0

# ------------------------------------------------------------
# Core runtime defaults (override via Docker / Unraid)
# ------------------------------------------------------------
ENV NODE_ENV=production \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    BIND_IP=0.0.0.0 \
    HOME=/app \
    METEOR_DISABLE_OPTIMISTIC_CACHING=1 \
    \
    MONGO_HOST=127.0.0.1 \
    MONGO_PORT=27017 \
    MONGO_DB=rocketchat \
    MONGO_RS=rs01 \
    \
    MAIL_URL=smtp://127.0.0.1:25 \
    \
    OVERWRITE_SETTING_Email_Enabled=true \
    OVERWRITE_SETTING_SMTP_Host=127.0.0.1 \
    OVERWRITE_SETTING_SMTP_Port=25 \
    OVERWRITE_SETTING_SMTP_Protocol=smtp \
    OVERWRITE_SETTING_SMTP_IgnoreTLS=true \
    OVERWRITE_SETTING_SMTP_From=rocketchat@localhost \
    \
    TRANSPORTER=nats://127.0.0.1:4222

# ------------------------------------------------------------
# Preseed Postfix (local only)
# ------------------------------------------------------------
RUN echo "postfix postfix/mailname string localhost" | debconf-set-selections && \
    echo "postfix postfix/main_mailer_type string 'Local only'" | debconf-set-selections

# ------------------------------------------------------------
# Base packages
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    unzip \
    python3 \
    build-essential \
    netcat-openbsd \
    gosu \
    tini \
    fontconfig \
    graphicsmagick \
    postfix \
    mc \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Node.js 22.x (REQUIRED by Rocket.Chat v7+)
# ------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    node -v && npm -v && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Deno (REQUIRED)
# ------------------------------------------------------------
RUN set -eux; \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "$dpkgArch" in \
      amd64) ARCH="x86_64" ;; \
      arm64) ARCH="aarch64" ;; \
      *) echo "Unsupported arch"; exit 1 ;; \
    esac; \
    curl -fsSL "https://dl.deno.land/release/v${DENO_VERSION}/deno-${ARCH}-unknown-linux-gnu.zip" -o /tmp/deno.zip; \
    unzip /tmp/deno.zip -d /usr/local/bin; \
    rm /tmp/deno.zip; \
    chmod +x /usr/local/bin/deno; \
    deno --version

# ------------------------------------------------------------
# MongoDB 8.0 (OFFICIAL)
# ------------------------------------------------------------
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://pgp.mongodb.com/server-8.0.asc | \
      gpg --dearmor -o /etc/apt/keyrings/mongodb-server-8.0.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/mongodb-server-8.0.gpg] \
      https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" \
      > /etc/apt/sources.list.d/mongodb-org-8.0.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends mongodb-org && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# NATS Server (local)
# ------------------------------------------------------------
RUN set -eux; \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "$dpkgArch" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported arch"; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/nats-io/nats-server/releases/download/v${NATS_VERSION}/nats-server-v${NATS_VERSION}-linux-${ARCH}.tar.gz" \
      -o /tmp/nats.tar.gz; \
    tar -xzf /tmp/nats.tar.gz -C /tmp; \
    mv /tmp/nats-server-v${NATS_VERSION}-linux-${ARCH}/nats-server /usr/local/bin/; \
    rm -rf /tmp/nats*

# ------------------------------------------------------------
# Runtime user (NO GROUP — matches your entry script)
# ------------------------------------------------------------
RUN useradd -r -M -d /app -s /usr/sbin/nologin rocketchat

# ------------------------------------------------------------
# Install Rocket.Chat (LATEST)
# ------------------------------------------------------------
WORKDIR /app
RUN curl -fSL https://releases.rocket.chat/latest/download -o rocket.chat.tgz && \
    tar -xzf rocket.chat.tgz && \
    rm rocket.chat.tgz

# ------------------------------------------------------------
# Install server dependencies
# ------------------------------------------------------------
WORKDIR /app/bundle/programs/server
RUN npm install --unsafe-perm=true --omit=dev --no-audit --no-fund && \
    npm cache clear --force

# ------------------------------------------------------------
# Filesystem layout (entrypoint-compatible)
# ------------------------------------------------------------
RUN mkdir -p \
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

EXPOSE 3000 4222 8222

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/rc-aio-entrypoint.sh"]
