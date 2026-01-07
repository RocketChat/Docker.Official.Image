FROM phusion/baseimage:noble-1.0.2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Versions (pinned)
# ------------------------------------------------------------
ENV RC_VERSION=7.13.2
ENV DENO_VERSION=1.43.5

# ------------------------------------------------------------
# Core runtime environment
# ------------------------------------------------------------
ENV NODE_ENV=production \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    BIND_IP=0.0.0.0 \
    MONGO_HOST=127.0.0.1 \
    MONGO_PORT=27017 \
    MONGO_DB=rocketchat \
    MONGO_RS=rs01 \
    HOME=/app \
    METEOR_DISABLE_OPTIMISTIC_CACHING=1 \
    MAIL_URL=smtp://127.0.0.1:25

# ------------------------------------------------------------
# Preseed Postfix (NON-INTERACTIVE, LOCAL ONLY)
# ------------------------------------------------------------
RUN echo "postfix postfix/mailname string localhost" | debconf-set-selections && \
    echo "postfix postfix/main_mailer_type string 'Local only'" | debconf-set-selections

# ------------------------------------------------------------
# Base packages + Ubuntu guide deps + SMTP
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
    mc \
    postfix \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Node.js 22.x (REQUIRED by Rocket.Chat 7.13.2)
# ------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    node -v && npm -v && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Deno (REQUIRED)
# ------------------------------------------------------------
RUN ARCH="" && dpkgArch="$(dpkg --print-architecture)" && \
    case "${dpkgArch##*-}" in \
      amd64) ARCH="x86_64" ;; \
      arm64) ARCH="aarch64" ;; \
      *) echo "unsupported Deno architecture"; exit 1 ;; \
    esac && \
    curl -fsSL "https://dl.deno.land/release/v${DENO_VERSION}/deno-${ARCH}-unknown-linux-gnu.zip" \
      -o /tmp/deno.zip && \
    unzip /tmp/deno.zip -d /usr/local/bin && \
    rm /tmp/deno.zip && \
    chmod 755 /usr/local/bin/deno && \
    deno --version

# ------------------------------------------------------------
# MongoDB 7.0 (jammy repo workaround for noble)
# ------------------------------------------------------------
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
      gpg --dearmor -o /etc/apt/keyrings/mongodb-server-7.0.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/mongodb-server-7.0.gpg] \
      https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" \
      > /etc/apt/sources.list.d/mongodb-org-7.0.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends mongodb-org && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# User (NO GROUP — uses nogroup)
# ------------------------------------------------------------
RUN useradd -r -M -d /app -s /usr/sbin/nologin rocketchat

# ------------------------------------------------------------
# Install Rocket.Chat bundle
# ------------------------------------------------------------
WORKDIR /app
RUN curl -fSL "https://releases.rocket.chat/${RC_VERSION}/download" \
    -o rocket.chat.tgz && \
    tar -xzf rocket.chat.tgz && \
    rm rocket.chat.tgz

# ------------------------------------------------------------
# Install server deps
# ------------------------------------------------------------
WORKDIR /app/bundle/programs/server
RUN npm install --unsafe-perm=true --omit=dev --no-audit --no-fund && \
    npm cache clear --force

# ------------------------------------------------------------
# Filesystem layout
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

EXPOSE 3000

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/rc-aio-entrypoint.sh"]
