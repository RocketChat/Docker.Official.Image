#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

url='https://github.com/RocketChat/Docker.Official.Image.git'

commit="$(git log -1 --format='format:%H' -- Dockerfile $(awk 'toupper($1) == "COPY" { for (i = 2; i < NF; i++) { print $i } }' Dockerfile))"
fullVersion="$(grep -m1 'ENV RC_VERSION ' ./Dockerfile | cut -d' ' -f3)"

cat <<EOF
Maintainers: Rocket.Chat Image Team <buildmaster@rocket.chat> (@RocketChat)
GitRepo: $url

Tags: $fullVersion, ${fullVersion%.*}, ${fullVersion%.*.*}, latest
GitCommit: $commit
EOF
