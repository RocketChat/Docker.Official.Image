FROM phusion/baseimage:noble-1.0.2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Rocket.Chat runtime expectations
# ------------------------------------------------------------
ENV NODE_ENV=production \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    MONGO_URL=mongodb://127.0.0.1:27017/rocketchat \
    DEPLOY_METHOD=docker \
    DEPLOY_PLATFORM=unraid \
    NODE_OPTIONS="--max-old-space-size=4096"

# ------------------------------------------------------------
# Base OS packages
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    python3 \
    make \
    g++ \
    wget \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# MongoDB Community Edition (mongodb-org) 7.0
# IMPORTANT: MongoDB does not publish a noble repo yet.
# Use jammy repo on noble (common container practice).
# ------------------------------------------------------------
RUN curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
      gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg && \
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
      https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" \
      > /etc/apt/sources.list.d/mongodb-org-7.0.list && \
    apt-get update && \
    apt-get install -y mongodb-org && \
    rm -rf /var/lib/apt/lists/*

# MongoDB persistent storage
VOLUME ["/var/lib/mongodb"]

# ------------------------------------------------------------
# Node.js 20 (matches Rocket.Chat official image major)
# ------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update && apt-get install -y nodejs && \
    node -v && npm -v && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Rocket.Chat bundle (official layout)
# ------------------------------------------------------------
WORKDIR /app

# Download latest Rocket.Chat bundle (you can pin this later)
RUN curl -L https://releases.rocket.chat/latest/download \
    -o rocket.chat.tgz && \
    tar -xzf rocket.chat.tgz && \
    rm rocket.chat.tgz && \
    mv bundle /app/bundle

# Install server-side node modules
WORKDIR /app/bundle/programs/server
RUN npm install --omit=dev

# ------------------------------------------------------------
# Rocket.Chat runtime user
# ------------------------------------------------------------
RUN useradd -r -u 999 -g nogroup rocketchat && \
    mkdir -p /var/lib/mongodb && \
    chown -R rocketchat:nogroup /app /var/lib/mongodb

# ------------------------------------------------------------
# runit services
# ------------------------------------------------------------
RUN mkdir -p /etc/service/mongodb /etc/service/rocketchat

COPY services/mongodb.run /etc/service/mongodb/run
COPY services/rocketchat.run /etc/service/rocketchat/run

RUN chmod +x /etc/service/*/run

EXPOSE 3000

CMD ["/sbin/my_init"]
