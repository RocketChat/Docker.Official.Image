#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Rocket.Chat AIO Entrypoint
# ============================================================

# ------------------------------------------------------------
# Environment defaults (override via Docker / Unraid template)
# ------------------------------------------------------------
: "${MONGO_HOST:=127.0.0.1}"
: "${MONGO_PORT:=27017}"
: "${MONGO_DB:=rocketchat}"
: "${MONGO_RS:=rs01}"
: "${PORT:=3000}"
: "${ROOT_URL:=http://localhost:3000}"
: "${MAIL_URL:=smtp://127.0.0.1:25}"

export BIND_IP="0.0.0.0"
export MONGO_URL="mongodb://${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB}?replicaSet=${MONGO_RS}"
export MONGO_OPLOG_URL="mongodb://${MONGO_HOST}:${MONGO_PORT}/local?replicaSet=${MONGO_RS}"
export MAIL_URL

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

# Dockerfile creates:
#   user  = rocketchat
#   group = nogroup
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
  echo "MONGO_HOST=${MONGO_HOST}"
  echo "MONGO_PORT=${MONGO_PORT}"
  echo "MONGO_DB=${MONGO_DB}"
  echo "MONGO_RS=${MONGO_RS}"
  echo "PORT=${PORT}"
  echo "ROOT_URL=${ROOT_URL}"
  echo "MAIL_URL=${MAIL_URL}"
  echo "MONGO_URL=${MONGO_URL}"
  echo "MONGO_OPLOG_URL=${MONGO_OPLOG_URL}"
} > "${DEBUGDIR}/env.txt"

echo "STARTUP $(date)" >> "${DEBUGDIR}/state.txt"

# ------------------------------------------------------------
# Start Postfix (local SMTP)
# ------------------------------------------------------------
echo "[AIO] Starting Postfix..."
service postfix start

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
# Wait until MongoDB accepts connections
# ------------------------------------------------------------
echo "[AIO] Waiting for MongoDB socket..."

for i in {1..60}; do
  if mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; then
    echo "Mongo reachable at $(date)" >> "${DEBUGDIR}/state.txt"
    break
  fi
  sleep 1
done

# ------------------------------------------------------------
# Replica set initialization (runs ONCE only)
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
      echo "Replica PRIMARY elected at $(date)" >> "${DEBUGDIR}/rs-init.log"
      break
    fi
    sleep 1
  done

  touch "${MARKER}"
  echo "Replica set initialized" >> "${DEBUGDIR}/state.txt"
else
  echo "[AIO] Replica set already initialized."
  echo "Replica set already initialized" >> "${DEBUGDIR}/state.txt"
fi

# ------------------------------------------------------------
# Final readiness gate (must be PRIMARY)
# ------------------------------------------------------------
for i in {1..60}; do
  if mongosh --quiet --eval 'db.hello().isWritablePrimary' | grep -q true; then
    echo "Mongo PRIMARY confirmed at $(date)" >> "${DEBUGDIR}/state.txt"
    break
  fi
  sleep 1
done

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
    MONGO_URL="${MONGO_URL}" \
    MONGO_OPLOG_URL="${MONGO_OPLOG_URL}" \
  node main.js
