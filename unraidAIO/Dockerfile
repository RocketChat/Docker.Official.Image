FROM phusion/baseimage:noble-1.0.2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Versions (pin these for repeatable builds)
# ------------------------------------------------------------
ENV RC_VERSION=7.13.2
ENV DENO_VERSION=1.43.5

# ------------------------------------------------------------
# Core runtime env (official-style defaults; override at runtime)
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
    METEOR_DISABLE_OPTIMISTIC_CACHING=1

# ------------------------------------------------------------
# Base packages + Ubuntu guide deps
#  - build-essential: via make/g++ (already explicit)
#  - graphicsmagick: required for image processing in RC
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    unzip \
    python3 \
    make \
    g++ \
    netcat-openbsd \
    gosu \
    tini \
    fontconfig \
    graphicsmagick \
    build-essential \
    mc \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Node.js 22.x (REQUIRED by Rocket.Chat 7.13.2)
# Keep bundled npm — DO NOT upgrade/downgrade npm
# ------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    node -v && npm -v && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Deno (REQUIRED by Rocket.Chat v7)
# Supported: >=1.37.1 and <2.0.0
# ------------------------------------------------------------
RUN ARCH="" && dpkgArch="$(dpkg --print-architecture)" && \
    case "${dpkgArch##*-}" in \
      amd64) ARCH="x86_64" ;; \
      arm64) ARCH="aarch64" ;; \
      *) echo "unsupported Deno architecture"; exit 1 ;; \
    esac && \
    set -eux && \
    curl -fsSL "https://dl.deno.land/release/v${DENO_VERSION}/deno-${ARCH}-unknown-linux-gnu.zip" \
      --output /tmp/deno.zip && \
    unzip /tmp/deno.zip -d /usr/local/bin && \
    rm /tmp/deno.zip && \
    chmod 755 /usr/local/bin/deno && \
    deno --version

# ------------------------------------------------------------
# MongoDB 7.0 (noble workaround: use jammy repo)
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
# Create dedicated user/group (DO NOT use nogroup)
# ------------------------------------------------------------
RUN groupadd -r rocketchat && \
    useradd -r -g rocketchat -d /app -s /usr/sbin/nologin rocketchat

# ------------------------------------------------------------
# Install Rocket.Chat bundle (pinned)
# ------------------------------------------------------------
WORKDIR /app
RUN set -eux && \
    curl -fSL "https://releases.rocket.chat/${RC_VERSION}/download" -o rocket.chat.tgz && \
    tar -xzf rocket.chat.tgz && \
    rm rocket.chat.tgz

# ------------------------------------------------------------
# Install server dependencies (Meteor bundle)
# Use --unsafe-perm because it can rebuild native deps in container
# ------------------------------------------------------------
WORKDIR /app/bundle/programs/server
RUN npm install --unsafe-perm=true --omit=dev --no-audit --no-fund && \
    npm cache clear --force

# ------------------------------------------------------------
# Filesystem layout + permissions (official-ish)
# ------------------------------------------------------------
RUN mkdir -p \
      /app/uploads \
      /var/lib/mongodb \
      /var/log/mongodb \
      /tmp/meteor && \
    chown -R rocketchat:rocketchat \
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
