#!/usr/bin/env bash

set -euo pipefail

target_dir="${1:-$(pwd)/files/grafana/dashboards}"

test -d "$target_dir" || {
  echo "$target_dir does not exist"
  exit 1
}

function download_dashboard() {
  local id=$1
  local version=$2
  local dest=$3
  url="https://grafana.com/api/dashboards/${id}/revisions/${version}/download"
  echo "$dest"
  if [ ! -f "$dest" ]; then
    echo "Downloading $url to $dest"
    curl -SsL -o "$dest" "$url"
    # shellcheck disable=SC2016
    sed -i 's/${DS_PROMETHEUS}/DS_PROMETHEUS/g' "$dest"
    # shellcheck disable=SC2016
    sed -i 's/${DS}/DS_PROMETHEUS/g' "$dest"
    # shellcheck disable=SC2016
    sed -i 's/${DS_NATS-PROMETHEUS}/DS_PROMETHEUS/g' "$dest"
    sed -E -i 's/now-[0-9]+[mh]/now-1h/g' "$dest" # all dashboards with 1 hour time range
    sed -i 's/now\/d/now-1h/g' "$dest" # all dashboards with 1 hour time range
  else
    echo "File $dest already exists, skipping download."
  fi
}

mkdir -p "$target_dir/imported/nats"
mkdir -p "$target_dir/imported/rocketchat"
mkdir -p "$target_dir/imported/mongodb"
mkdir -p "$target_dir/imported/prometheus"



download_dashboard \
  2 \
  latest \
  "$target_dir/imported/prometheus/prometheus-stats.json"

download_dashboard \
  1860 \
  latest \
  "$target_dir/imported/prometheus/node-exporter-full.json"

download_dashboard \
  23428 \
  latest \
  "$target_dir/imported/rocketchat/rocketchat-metrics.json"

download_dashboard \
  2279 \
  latest \
  "$target_dir/imported/nats/nats-server.json"

download_dashboard \
  23712 \
  latest \
  "$target_dir/imported/mongodb/mongodb-exporter.json"
