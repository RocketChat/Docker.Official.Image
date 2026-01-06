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
# Base OS packages + MongoDB (Ubuntu-native)
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    python3 \
    make \
    g++ \
    wget \
    mongodb-server \
    && rm -rf /var/lib/apt/lists/*

# MongoDB persistent storage (Ubuntu default)
VOLUME ["/var/lib/mongodb"]

# ------------------------------------------------------------
# Node.js (match official Rocket.Chat image)
# ------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    node -v && npm -v

# ------------------------------------------------------------
# Rocket.Chat bundle (official layout)
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
# Rocket.Chat runtime user
# ------------------------------------------------------------
RUN useradd -r -u 999 rocketchat && \
    chown -R rocketchat:rocketchat /app /var/lib/mongodb

# ------------------------------------------------------------
# runit services
# ------------------------------------------------------------
RUN mkdir -p /etc/service/mongodb /etc/service/rocketchat

COPY services/mongodb.run /etc/service/mongodb/run
COPY services/rocketchat.run /etc/service/rocketchat/run

RUN chmod +x /etc/service/*/run

EXPOSE 3000

CMD ["/sbin/my_init"]
