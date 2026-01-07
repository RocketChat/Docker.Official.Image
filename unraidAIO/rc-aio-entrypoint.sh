#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Rocket.Chat AIO – MongoDB + Rocket.Chat Entrypoint
#
# - Runs MongoDB in foreground (Docker-safe)
# - Initializes replica set ONCE
# - Survives Docker restarts cleanly
# - Writes persistent debug state to disk
# ============================================================

# ------------------------------------------------------------
# Environment defaults
# ------------------------------------------------------------
: "${MONGO_HOST:=127.0.0.1}"
: "${MONGO_PORT:=27017}"
: "${MONGO_DB:=rocketchat}"
: "${MONGO_RS:=rs01}"
: "${PORT:=3000}"
: "${ROOT_URL:=http://localhost:3000}"

export MONGO_URL="mongodb://${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB}?replicaSet=${MONGO_RS}"
export MONGO_OPLOG_URL="mongodb://${MONGO_HOST}:${MONGO_PORT}/local?replicaSet=${MONGO_RS}"
export BIND_IP="0.0.0.0"

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------
DBPATH="/var/lib/mongodb"
LOGPATH="/var/log/mongodb/mongod.log"
DEBUGDIR="${DBPATH}/dbdebug"
MARKER="${DBPATH}/.rs-initialized"

# ------------------------------------------------------------
# Prepare filesystem (persistent + debuggable)
# ------------------------------------------------------------
mkdir -p \
  "${DBPATH}" \
  "$(dirname "${LOGPATH}")" \
  "${DEBUGDIR}"

chown -R rocketchat:rocketchat \
  "${DBPATH}" \
  "$(dirname "${LOGPATH}")"

# ------------------------------------------------------------
# Write startup environment snapshot (for debugging)
# ------------------------------------------------------------
{
  echo "=== Rocket.Chat AIO Mongo Debug ==="
  date
  echo
  echo "MONGO_HOST=${MONGO_HOST}"
  echo "MONGO_PORT=${MONGO_PORT}"
  echo "MONGO_DB=${MONGO_DB}"
  echo "MONGO_RS=${MONGO_RS}"
  echo "PORT=${PORT}"
  echo "ROOT_URL=${ROOT_URL}"
  echo "MONGO_URL=${MONGO_URL}"
  echo "MONGO_OPLOG_URL=${MONGO_OPLOG_URL}"
} > "${DEBUGDIR}/env.txt"

echo "STARTUP $(date)" >> "${DEBUGDIR}/state.txt"

# ------------------------------------------------------------
# Start MongoDB (FOREGROUND – Docker supervises lifecycle)
# ------------------------------------------------------------
echo "[AIO] Starting MongoDB (foreground)..."
echo "Starting mongod at $(date)" >> "${DEBUGDIR}/mongo-start.log"

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
# Wait for MongoDB socket (basic liveness)
# ------------------------------------------------------------
echo "[AIO] Waiting for MongoDB to accept connections..."
echo "Waiting for Mongo socket..." >> "${DEBUGDIR}/state.txt"

for i in {1..60}; do
  if mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; then
    echo "Mongo responded to ping at $(date)" >> "${DEBUGDIR}/state.txt"
    break
  fi
  sleep 1
done

# ------------------------------------------------------------
# Initialize replica set ONCE (IDEMPOTENT + SAFE)
# ------------------------------------------------------------
if [ ! -f "${MARKER}" ]; then
  echo "[AIO] First-time replica set initialization..."
  echo "Replica set init starting at $(date)" >> "${DEBUGDIR}/rs-init.log"

  # rs.initiate MAY fail harmlessly if partially initialized
  # Never let this crash the container under `set -e`
  mongosh --quiet <<EOF >> "${DEBUGDIR}/rs-init.log" 2>&1 || true
rs.initiate({
  _id: "${MONGO_RS}",
  members: [{ _id: 0, host: "${MONGO_HOST}:${MONGO_PORT}" }]
})
EOF

  echo "[AIO] Waiting for PRIMARY..."
  for i in {1..60}; do
    if mongosh --quiet --eval 'db.hello().isWritablePrimary' | grep -q true; then
      echo "Mongo PRIMARY elected at $(date)" >> "${DEBUGDIR}/rs-init.log"
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
# Final readiness gate (Mongo must be PRIMARY)
# ------------------------------------------------------------
echo "Final Mongo PRIMARY check..." >> "${DEBUGDIR}/state.txt"

for i in {1..60}; do
  if mongosh --quiet --eval 'db.hello().isWritablePrimary' | grep -q true; then
    echo "Mongo confirmed PRIMARY at $(date)" >> "${DEBUGDIR}/state.txt"
    break
  fi
  sleep 1
done

# ------------------------------------------------------------
# Start Rocket.Chat (explicit env injection)
# ------------------------------------------------------------
echo "[AIO] Starting Rocket.Chat on ${BIND_IP}:${PORT} ..."
echo "Starting Rocket.Chat at $(date)" >> "${DEBUGDIR}/state.txt"

cd /app/bundle

exec gosu rocketchat \
  env PORT="${PORT}" \
      ROOT_URL="${ROOT_URL}" \
      BIND_IP="${BIND_IP}" \
      MONGO_URL="${MONGO_URL}" \
      MONGO_OPLOG_URL="${MONGO_OPLOG_URL}" \
  node main.js
