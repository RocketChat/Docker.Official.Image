# Use the OFFICIAL Rocket.Chat image (already Node 22 compatible)
FROM registry.rocket.chat/rocketchat/rocket.chat:7.13.2

USER root

# ------------------------------------------------------------
# Install MongoDB Community Edition 7.0
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
      gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] \
      https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" \
      > /etc/apt/sources.list.d/mongodb-org-7.0.list && \
    apt-get update && \
    apt-get install -y mongodb-org && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# MongoDB data
# ------------------------------------------------------------
VOLUME ["/var/lib/mongodb"]

# ------------------------------------------------------------
# runit services
# ------------------------------------------------------------
RUN mkdir -p \
    /etc/service/mongodb \
    /etc/service/mongo-init

COPY services/mongodb.run     /etc/service/mongodb/run
COPY services/mongo-init.run  /etc/service/mongo-init/run

RUN chmod +x /etc/service/*/run

# Rocket.Chat already exposes 3000
EXPOSE 3000

# ------------------------------------------------------------
# Launch
# ------------------------------------------------------------
CMD ["/sbin/my_init"]
