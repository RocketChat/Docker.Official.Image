#!/bin/bash

set -ue

cd "$(cd "${0%/*}" && pwd -P)"

versions=( */ )

url='https://github.com/RocketChat/Rocket.Chat.git'

get_latest() {
  git ls-remote --tags $url \
      | awk -F 'refs/tags/' '
        $2 ~ /^v?[0-9]/ {
          gsub(/^v|\^.*/, "", $2);
          print $2;
        }
      ' \
      | sort -uV \
      | grep -vE -- '-(rc|alpha|beta)' \
      | grep "^${1}" \
      | tail -1
}

for version in "${versions[@]%/}"; do
  if [ -f "${version}/Dockerfile" ]; then
    sed -ri 's/^(ENV RC_VERSION) .*/\1 '"$(get_latest "${version}")"'/;' "${version}/Dockerfile"
  fi
done;
