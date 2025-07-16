#!/usr/bin/env bash

set -euo pipefail

# Check for Docker or Podman
if ! command -v docker >/dev/null 2>&1 && ! command -v podman >/dev/null 2>&1; then
  echo "Error: This script requires Docker or Podman to be installed and available in your PATH."
  echo "Please install Docker (https://docs.rocket.chat/docs/deploy-with-docker-docker-compose) or Podman (https://docs.rocket.chat/docs/deploy-with-podman)."
  exit 1
fi

files=(
  "compose-mongodb.yml"
  "compose-monitoring.yml"
  "compose-nats.yml"
  "compose-traefik.yml"
  "compose.yml"
  "rocketchat.sh"
)

for file in "${files[@]}"; do
  [[ -f "$file" ]] &&
    continue

  curl \
    -o "$file" \
    "https://raw.githubusercontent.com/RocketChat/Docker.Official.Image/main/$file"
done

# default env
PROMETHEUS_SCRAPE_INTERVAL="60s"
PROMETHEUS_RETENTION_SIZE="15GB"
PROMETHEUS_RETENTION_TIME="15d"
TRAEFIK_API_INSECURE=false
DOCKER_GATEWAY=172.17.0.1
LETSENCRYPT_EMAIL=
REG_TOKEN=
DOMAIN=
GRAFANA_DOMAIN=
PROMETHEUS_SCRAPE_INTERVAL=60s
PROMETHEUS_RETENTION_SIZE=15GB
PROMETHEUS_RETENTION_TIME=15d
TRAEFIK_API_INSECURE=false
# default to everything, user have to change the env file manually to change this behaviour
COMPOSE_MONGO_ENABLED=y
COMPOSE_NATS_ENABLED=y
COMPOSE_TRAEFIK_ENABLED=y
COMPOSE_ROCKETCHAT_ENABLED=y
COMPOSE_MONITORING_ENABLED=y
# Enable or disable https
COMPOSE_HTTPS=
# Prometheus will only be enabled in local network since it does not offer any kind of secure access
PROMETHEUS_DOMAIN=prometheus.localhost
# Traefik bind ports
TRAEFIK_HTTP_PORT=80
TRAEFIK_HTTPS_PORT=443
TRAEFIK_DASHBOARD_PORT=8080

read_yn() {
  local prompt="$1"
  local default="$2"
  local answer

  # Loop until a valid answer is provided.
  while true; do
    read -rp "$prompt (y/n, default: $default): " answer

    # Handle the default case (user just presses Enter).
    [[ -z "$answer" ]] &&
      answer="$default"

    # Convert to lowercase to simplify validation.
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

    # Check if the answer is either 'y' or 'n'.
    if [[ "$answer" == "y" || "$answer" == "n" ]]; then
      echo "$answer"
      return 0 # Success
    fi
  done
}

save_env() {
  cat <<EOF >.env
# Sane devs
BIND_IP=${BIND_IP:-0.0.0.0}
ALLOW_EMPTY_PASSWORD=${ALLOW_EMPTY_PASSWORD:-yes}
DEPLOY_PLATFORM=${DEPLOY_PLATFORM:-docker}
GRAFANA_VERSION=${GRAFANA_VERSION:-}
IMAGE=${IMAGE:-}
RELEASE=${RELEASE:-}
PROMETHEUS_VERSION=${PROMETHEUS_VERSION:-}
MONGODB_ENABLE_JOURNAL=${MONGODB_ENABLE_JOURNAL:-}
MONGODB_EXPORTER_VERSION=${MONGODB_ENABLE_JOURNAL:-}
MONGODB_VERSION=${MONGODB_VERSION:-}
NATS_EXPORTER_VERSION=${NATS_EXPORTER_VERSION:-}
NATS_URL=${NATS_URL:-}
NATS_VERSION=${NATS_VERSION:-}



# Rocketchat Variables
REG_TOKEN=${REG_TOKEN:-}
MONGO_URL=${MONGO_URL:-}
PORT=${PORT:-}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-}
DOCKER_GATEWAY=${DOCKER_GATEWAY:-}
DOMAIN=${DOMAIN:-localhost}
GRAFANA_DOMAIN=${GRAFANA_DOMAIN:-grafana.localhost}
PROMETHEUS_SCRAPE_INTERVAL=${PROMETHEUS_SCRAPE_INTERVAL:-60s}
PROMETHEUS_RETENTION_SIZE=${PROMETHEUS_RETENTION_SIZE:-15GB}
PROMETHEUS_RETENTION_TIME=${PROMETHEUS_RETENTION_TIME:-15d}
TRAEFIK_API_INSECURE=${TRAEFIK_API_INSECURE:-false}
COMPOSE_MONGO_ENABLED=${COMPOSE_MONGO_ENABLED:-}
ROOT_URL=http://${DOMAIN:-localhost}

# Enabled services
COMPOSE_NATS_ENABLED=${COMPOSE_NATS_ENABLED:-}
COMPOSE_TRAEFIK_ENABLED=${COMPOSE_TRAEFIK_ENABLED:-}
COMPOSE_ROCKETCHAT_ENABLED=${COMPOSE_ROCKETCHAT_ENABLED:-}
COMPOSE_MONITORING_ENABLED=${COMPOSE_MONITORING_ENABLED:-}
COMPOSE_HTTPS=${COMPOSE_HTTPS:-}
PROMETHEUS_DOMAIN=${PROMETHEUS_DOMAIN}

# Traefik ports
TRAEFIK_HTTP_PORT=${TRAEFIK_HTTP_PORT}
TRAEFIK_DASHBOARD_PORT=${TRAEFIK_DASHBOARD_PORT}
TRAEFIK_HTTPS_PORT=${TRAEFIK_HTTPS_PORT}

# By default prometheus only on localhost
PROMETHEUS_LISTEN_ADDR=${PROMETHEUS_LISTEN_ADDR:-127.0.0.1}

COMPOSE_PROJECT=${COMPOSE_PROJECT:-}
EOF
}

# shellcheck disable=SC1091
[[ -f ".env" ]] &&
  source ".env"

# check if the REG_TOKEN is set, if not, ask the user for it
# shellcheck disable=SC2143
[[ -z "${REG_TOKEN:-}" && -z "$(grep REG_TOKEN .env)" ]] &&
  read -rp "Enter REG_TOKEN (or leave blank to skip): " REG_TOKEN &&
  save_env

{
  [[ -z "${COMPOSE_HTTPS:-}" ]] &&
    COMPOSE_HTTPS=$(read_yn "Enable HTTPS for Traefik? Recommended if service will be available to the internet" "n")

  if [[ "$COMPOSE_HTTPS" == "y" ]]; then
    while [[ -z "${LETSENCRYPT_EMAIL:-}" ]]; do
      read -rp "Enter LETSENCRYPT_EMAIL: " LETSENCRYPT_EMAIL
    done
  fi

  save_env
}

# if the domain is empty, and the user wan't the default, we just check again and set a default
[[ -z "${DOMAIN}" ]] &&
  read -rp "Enter DOMAIN (default: localhost): " DOMAIN &&
  [[ -z "${DOMAIN}" ]] &&
  DOMAIN=localhost &&
  save_env

[[ -z "${GRAFANA_DOMAIN}" ]] &&
  read -rp "Enter GRAFANA_DOMAIN (default: grafana.localhost): " GRAFANA_DOMAIN &&
  [[ -z "${GRAFANA_DOMAIN}" ]] &&
  GRAFANA_DOMAIN=grafana.localhost &&
  save_env

# for podman we need to use this to query the node exporter
command -v podman 2>/dev/null &&
  DOCKER_GATEWAY="host.containers.internal" &&
  save_env

# We append both the file and the profile for compatibility with older podman-compose versions
# where the profile don't quite work well (version >1.0.6)
declare -a COMPOSE_ARGS=()
[[ "${COMPOSE_MONITORING_ENABLED}" == "y" ]] &&
  COMPOSE_ARGS+=("--profile=monitoring" "--file=compose-monitoring.yml")

[[ "${COMPOSE_MONGO_ENABLED}" == "y" ]] &&
  COMPOSE_ARGS+=("--profile=mongodb" "--file=compose-mongodb.yml") &&
  [[ "${COMPOSE_MONITORING_ENABLED}" == "y" ]] &&
  COMPOSE_ARGS+=("--profile=mongodb-exporter")

[[ "${COMPOSE_NATS_ENABLED}" == "y" ]] &&
  COMPOSE_ARGS+=("--profile=nats" "--file=compose-nats.yml") &&
  [[ "${COMPOSE_MONITORING_ENABLED}" == "y" ]] &&
  COMPOSE_ARGS+=("--profile=nats-exporter")

[[ "${COMPOSE_ROCKETCHAT_ENABLED}" == "y" ]] &&
  COMPOSE_ARGS+=("--profile=rocketchat" "--file=compose.yml") &&
  [[ "${COMPOSE_MONITORING_ENABLED}" == "y" ]] &&
  COMPOSE_ARGS+=("--profile=rocketchat-exporter")

if [[ "${COMPOSE_TRAEFIK_ENABLED}" == "y" ]]; then
  COMPOSE_ARGS+=("--profile=traefik" "--file=compose-traefik.yml")

  [[ "${COMPOSE_HTTPS}" == "y" ]] &&
    COMPOSE_ARGS+=("--profile=https")
  [[ "${COMPOSE_HTTPS}" == "n" ]] &&
    COMPOSE_ARGS+=("--profile=http")
fi

save_env

compose_cmd() {
  # Which docker command to use
  DOCKER="$(command -v docker || command -v podman)"
  echo "${DOCKER}" "compose" "--project-name=${COMPOSE_PROJECT:-rocketchat}" "${COMPOSE_ARGS[@]}" "$@"
  "${DOCKER}" "compose" "--project-name=${COMPOSE_PROJECT:-rocketchat}" "${COMPOSE_ARGS[@]}" "$@"
}

if [[ -z "${*}" ]]; then
  compose_cmd up -d --remove-orphans
else
  compose_cmd "$@"
fi
