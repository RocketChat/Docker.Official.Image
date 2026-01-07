#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Rocket.Chat AIO Entrypoint
# ============================================================

# ------------------------------------------------------------
# Environment defaults (override via Docker / Unraid)
# ------------------------------------------------------------
: "${MONGO_HOST:=127.0.0.1}"
: "${MONGO_PORT:=27017}"
: "${MONGO_DB:=rocketchat}"
: "${MONGO_RS:=rs01}"
: "${PORT:=3000}"
: "${ROOT_URL:=http://localhost:3000}"
: "${MAIL_URL:=smtp://127.0.0.1:25}"
: "${TRANSPORTER:=nats://127.0.0.1:4222}"

export BIND_IP="0.0.0.0"
export MAIL_URL
export TRANSPORTER

export MONGO_URL="mongodb://${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB}?replicaSet=${MONGO_RS}"
export MONGO_OPLOG_URL="mongodb://${MONGO_HOST}:${MONGO_PORT}/local?replicaSet=${MONGO_RS}"

# ------------------------------------------------------------
# Filesystem layout
# ------------------------------------------------------------
DBPATH="/var/lib/mongodb"
LOGDIR="/var/log/mongodb"
LOGPATH="${LOGDIR}/mongod.log"
DEBUGDIR="${DBPATH}/dbdebug"
MARKER="${DBPATH}/.rs-initialized"

# ------------------------------------------------------------
# Prepare persistent directories
# ------------------------------------------------------------
mkdir -p "${DBPATH}" "${LOGDIR}" "${DEBUGDIR}"

chown -R rocketchat:nogroup \
  "${DBPATH}" \
  "${LOGDIR}"

# ------------------------------------------------------------
# Persist startup environment for debugging
# ------------------------------------------------------------
{
  echo "=== Rocket.Chat AIO Debug Snapshot ==="
  date
  echo
  env | sort
} > "${DEBUGDIR}/env.txt"

echo "STARTUP $(date)" >> "${DEBUGDIR}/state.txt"

# ------------------------------------------------------------
# Start Postfix (local SMTP)
# ------------------------------------------------------------
echo "[AIO] Starting Postfix..."
service postfix start

# ------------------------------------------------------------
# Send local SMTP test email (non-fatal)
# ------------------------------------------------------------
echo "[AIO] Sending local SMTP test email..."
{
  echo "Subject: Rocket.Chat AIO startup test"
  echo "From: rocketchat@localhost"
  echo "To: root@localhost"
  echo
  echo "Rocket.Chat container started successfully at $(date)."
} | sendmail -t || true

# ------------------------------------------------------------
# Start NATS
# ------------------------------------------------------------
echo "[AIO] Starting NATS..."
nats-server \
  --addr 127.0.0.1 \
  --port 4222 \
  --http_port 8222 \
  >> "${DEBUGDIR}/nats.log" 2>&1 &

NATS_PID=$!
echo "${NATS_PID}" > "${DEBUGDIR}/nats.pid"
echo "NATS PID=${NATS_PID}" >> "${DEBUGDIR}/state.txt"

# ------------------------------------------------------------
# Start MongoDB (no --fork; Docker supervises lifecycle)
# ------------------------------------------------------------
echo "[AIO] Starting MongoDB..."
echo "mongod start: $(date)" >> "${DEBUGDIR}/mongo.log"

gosu rocketchat mongod \
  --dbpath "${DBPATH}" \
  --bind_ip "${MONGO_HOST}" \
  --port "${MONGO_PORT}" \
  --replSet "${MONGO_RS}" \
  --oplogSize 128 \
  --logpath "${LOGPATH}" \
  --logappend &

MONGO_PID=$!
echo "${MONGO_PID}" > "${DEBUGDIR}/mongo.pid"
echo "Mongo PID=${MONGO_PID}" >> "${DEBUGDIR}/state.txt"

# ------------------------------------------------------------
# Wait for MongoDB socket
# ------------------------------------------------------------
echo "[AIO] Waiting for MongoDB socket..."
for i in {1..60}; do
  if mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# ------------------------------------------------------------
# Replica set initialization (ONCE)
# ------------------------------------------------------------
if [ ! -f "${MARKER}" ]; then
  echo "[AIO] Initializing MongoDB replica set..."

  mongosh --quiet <<EOF >> "${DEBUGDIR}/rs-init.log" 2>&1 || true
rs.initiate({
  _id: "${MONGO_RS}",
  members: [{ _id: 0, host: "${MONGO_HOST}:${MONGO_PORT}" }]
})
EOF

  for i in {1..60}; do
    if mongosh --quiet --eval 'db.hello().isWritablePrimary' | grep -q true; then
      break
    fi
    sleep 1
  done

  touch "${MARKER}"
  echo "Replica set initialized" >> "${DEBUGDIR}/state.txt"
else
  echo "[AIO] Replica set already initialized."
fi

# ------------------------------------------------------------
# Final Mongo readiness gate
# ------------------------------------------------------------
for i in {1..60}; do
  if mongosh --quiet --eval 'db.hello().isWritablePrimary' | grep -q true; then
    break
  fi
  sleep 1
done

echo "Mongo PRIMARY confirmed" >> "${DEBUGDIR}/state.txt"

# ------------------------------------------------------------
# Launch Rocket.Chat
# ------------------------------------------------------------
echo "[AIO] Starting Rocket.Chat on ${BIND_IP}:${PORT} ..."
echo "Rocket.Chat start: $(date)" >> "${DEBUGDIR}/state.txt"

cd /app/bundle

exec gosu rocketchat \
  env \
    PORT="${PORT}" \
    ROOT_URL="${ROOT_URL}" \
    BIND_IP="${BIND_IP}" \
    MAIL_URL="${MAIL_URL}" \
    TRANSPORTER="${TRANSPORTER}" \
    MONGO_URL="${MONGO_URL}" \
    MONGO_OPLOG_URL="${MONGO_OPLOG_URL}" \
  node main.js
