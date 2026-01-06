FROM phusion/baseimage:noble-1.0.2

# ------------------------------------------------------------
# Shell + environment
# ------------------------------------------------------------
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

ENV NODE_ENV=production \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    MONGO_URL="mongodb://127.0.0.1:27017/rocketchat?replicaSet=rs01" \
    DEPLOY_METHOD=docker \
    DEPLOY_PLATFORM=unraid \
    NODE_OPTIONS="--max-old-space-size=4096"

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
    wget \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# MongoDB Community Edition 7.0
# (jammy repo on noble – required)
# ------------------------------------------------------------
RUN curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
        gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] \
        https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" \
        > /etc/apt/sources.list.d/mongodb-org-7.0.list && \
    apt-get update && \
    apt-get install -y mongodb-org && \
    rm -rf /var/lib/apt/lists/*

VOLUME ["/var/lib/mongodb"]

# ------------------------------------------------------------
# Node.js 20
# ------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs && \
    node -v && npm -v && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Rocket.Chat bundle (official layout)
# ------------------------------------------------------------
WORKDIR /app

RUN curl -L https://releases.rocket.chat/latest/download \
      -o rocket.chat.tgz && \
    tar -xzf rocket.chat.tgz && \
    rm rocket.chat.tgz

# ------------------------------------------------------------
# Install Rocket.Chat server dependencies
# ------------------------------------------------------------
WORKDIR /app/bundle/programs/server
RUN npm install --omit=dev

# ------------------------------------------------------------
# Runtime user
# ------------------------------------------------------------
RUN useradd -r -u 999 -g nogroup rocketchat && \
    mkdir -p /var/lib/mongodb && \
    chown -R rocketchat:nogroup /app /var/lib/mongodb

# ------------------------------------------------------------
# runit services
# ------------------------------------------------------------
RUN mkdir -p \
    /etc/service/mongodb \
    /etc/service/mongo-init \
    /etc/service/rocketchat

COPY services/mongodb.run     /etc/service/mongodb/run
COPY services/mongo-init.run  /etc/service/mongo-init/run
COPY services/rocketchat.run  /etc/service/rocketchat/run

RUN chmod +x /etc/service/*/run

EXPOSE 3000

CMD ["/sbin/my_init"]
