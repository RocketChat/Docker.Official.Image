FROM phusion/baseimage:noble-1.0.2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

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
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Node.js 22.x (keep bundled npm — DO NOT upgrade npm)
# ------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs && \
    node -v && npm -v && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# MongoDB Community Edition 7.0
# NOTE: noble has no mongo repo → use jammy (REQUIRED)
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
# Rocket.Chat bundle (official prebuilt)
# ------------------------------------------------------------
WORKDIR /app

RUN curl -L https://releases.rocket.chat/latest/download \
    -o rocket.chat.tgz && \
    tar -xzf rocket.chat.tgz && \
    rm rocket.chat.tgz

WORKDIR /app/bundle/programs/server
RUN npm install --omit=dev

# ------------------------------------------------------------
# Runtime user (CORRECT: reuse existing nogroup)
# ------------------------------------------------------------
RUN useradd -r -u 999 -g nogroup -d /app rocketchat && \
    mkdir -p /var/lib/mongodb /var/log/mongodb && \
    chown -R rocketchat:nogroup \
      /app \
      /var/lib/mongodb \
      /var/log/mongodb

VOLUME ["/var/lib/mongodb"]

# ------------------------------------------------------------
# Entrypoint
# ------------------------------------------------------------
COPY rc-aio-entrypoint.sh /usr/local/bin/rc-aio-entrypoint.sh
RUN chmod +x /usr/local/bin/rc-aio-entrypoint.sh

EXPOSE 3000
CMD ["/usr/local/bin/rc-aio-entrypoint.sh"]
