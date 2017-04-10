#!/bin/bash
set -eo pipefail

current="$(
	git ls-remote --tags https://github.com/RocketChat/Rocket.Chat.git \
		| awk -F 'refs/tags/' '
			$2 ~ /^v?[0-9]/ {
				gsub(/^v|\^.*/, "", $2);
				print $2;
			}
		' \
		| sort -uV \
		| tail -1
)"

set -x
if [[ ! $current =~ ^[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+ ]]; then
        sed -ri 's/^(ENV RC_VERSION) .*/\1 '"$current"'/;' ./Dockerfile
fi
