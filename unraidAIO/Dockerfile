FROM phusion/baseimage:noble-1.0.2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Rocket.Chat expected runtime variables (official defaults)
# ------------------------------------------------------------
ENV NODE_ENV=production \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    MONGO_URL=mongodb://127.0.0.1:27017/rocketchat \
    DEPLOY_METHOD=docker \
    DEPLOY_PLATFORM=unraid \
    NODE_OPTIONS="--max-old-space-size=4096"

# ------------------------------------------------------------
# Base dependencies
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    python3 \
    make \
    g++ \
    wget \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# MongoDB 6.0 (official repo)
# ------------------------------------------------------------
RUN curl -fsSL https://pgp.mongodb.com/server-6.0.asc | \
    gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg] \
    https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/6.0 multiverse" \
    > /etc/apt/sources.list.d/mongodb-org-6.0.list && \
    apt-get update && apt-get install -y mongodb-org && \
    rm -rf /var/lib/apt/lists/*

VOLUME ["/data/db"]

# ------------------------------------------------------------
# Node.js (match official image major version)
# Rocket.Chat 7.x expects Node 20
# ------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    node -v && npm -v

# ------------------------------------------------------------
# Rocket.Chat bundle (official method)
# ------------------------------------------------------------
WORKDIR /app

RUN curl -L https://releases.rocket.chat/latest/download \
    -o rocket.chat.tgz && \
    tar -xzf rocket.chat.tgz && \
    rm rocket.chat.tgz && \
    mv bundle /app/bundle

WORKDIR /app/bundle/programs/server
RUN npm install --omit=dev

# ------------------------------------------------------------
# Non-root user (official behavior)
# ------------------------------------------------------------
RUN useradd -r -u 999 rocketchat && \
    chown -R rocketchat:rocketchat /app /data

# ------------------------------------------------------------
# runit services
# ------------------------------------------------------------
RUN mkdir -p /etc/service/mongodb /etc/service/rocketchat

COPY mongodb.run /etc/service/mongodb/run
COPY rocketchat.run /etc/service/rocketchat/run

RUN chmod +x /etc/service/*/run

EXPOSE 3000

CMD ["/sbin/my_init"]
