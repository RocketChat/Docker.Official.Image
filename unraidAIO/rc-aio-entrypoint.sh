#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Environment defaults
# -------------------------------
: "${MONGO_HOST:=127.0.0.1}"
: "${MONGO_PORT:=27017}"
: "${MONGO_DB:=rocketchat}"
: "${MONGO_RS:=rs01}"
: "${PORT:=3000}"
: "${ROOT_URL:=http://localhost:3000}"

export MONGO_URL="mongodb://${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB}?replicaSet=${MONGO_RS}"
export MONGO_OPLOG_URL="mongodb://${MONGO_HOST}:${MONGO_PORT}/local?replicaSet=${MONGO_RS}"
export BIND_IP="0.0.0.0"

DBPATH="/var/lib/mongodb"
LOGPATH="/var/log/mongodb/mongod.log"

# -------------------------------
# Start MongoDB
# -------------------------------
mkdir -p "$DBPATH" /var/log/mongodb
chown -R rocketchat:nogroup "$DBPATH" /var/log/mongodb

echo "[AIO] Starting MongoDB..."
gosu rocketchat mongod \
  --dbpath "$DBPATH" \
  --bind_ip "$MONGO_HOST" \
  --port "$MONGO_PORT" \
  --replSet "$MONGO_RS" \
  --oplogSize 128 \
  --logpath "$LOGPATH" \
  --logappend \
  --fork

# -------------------------------
# Wait for MongoDB
# -------------------------------
echo "[AIO] Waiting for MongoDB..."
for i in {1..60}; do
  if mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# -------------------------------
# Init replica set (once)
# -------------------------------
if ! mongosh --quiet --eval 'rs.status().ok' >/dev/null 2>&1; then
  echo "[AIO] Initializing replica set..."
  mongosh --quiet <<EOF
rs.initiate({
  _id: "${MONGO_RS}",
  members: [{ _id: 0, host: "${MONGO_HOST}:${MONGO_PORT}" }]
})
EOF
fi

# -------------------------------
# Wait for PRIMARY
# -------------------------------
for i in {1..60}; do
  if mongosh --quiet --eval 'db.hello().isWritablePrimary' | grep -q true; then
    break
  fi
  sleep 1
done

# -------------------------------
# Start Rocket.Chat
# -------------------------------
echo "[AIO] Starting Rocket.Chat..."
cd /app/bundle
exec gosu rocketchat node main.js
