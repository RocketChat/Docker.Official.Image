#!/bin/bash -ex
set -o pipefail

current="$(url=`curl -Ls -o /dev/null -w %{url_effective} https://github.com/RocketChat/Rocket.Chat/releases/latest`;echo $url | rev | cut -d'/' -f1 | rev | sed 's/v//')"

sed -ri 's/^(ENV RC_VERSION) .*/\1 '"$current"'/;' ./Dockerfile
