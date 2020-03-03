#!/bin/bash
set -e
. functions.sh

# Used dynamically: print "$array_" $1
array_2='2'
array_3='3 latest'

cd "$(cd "${0%/*}" && pwd -P)"
self="$(basename "${BASH_SOURCE[0]}")"

url='https://github.com/RocketChat/Docker.Official.Image'

# get the most recent commit which modified any of "$@"
fileCommit() {
  git log -1 --format='format:%H' HEAD -- "$@"
}

IFS=' ' read -ra versions <<< "$(get_versions)"
IFS=' ' read -ra versions <<< "$(sort_versions "${versions[@]}")"

get_stub() {
  local version="${1}"
  shift
  # IFS='/' read -ra versionparts <<< "${version}"
  local stub
  eval stub="$(echo "${version}" | awk -F. '{ print "$array_" $1 }')"
  echo "${stub}"
}

echo "# this file is generated via ${url}/blob/$(fileCommit "${self}")/${self}"
echo
echo "Maintainers: Rocket.Chat Image Team <buildmaster@rocket.chat> (@RocketChat)"
echo "GitRepo: ${url}.git"
echo

# prints "$2$1$3$1...$N"
join() {
  local sep="$1"
  shift
  local out
  printf -v out "${sep//%/%%}%s" "$@"
  echo "${out#$sep}"
}

for version in "${versions[@]}"; do
  # Skip "docs" and other non-docker directories
  [ -f "${version}/Dockerfile" ] || continue

  stub=$(get_stub "${version}")

  commit="$(fileCommit "${version}")"
  fullVersion="$(get_tag "${version}" full)"
  majorMinorVersion="$(get_tag "${version}" majorminor)"

  IFS=' ' read -ra versionAliases <<< "$fullVersion $majorMinorVersion $stub"

  echo "Tags: $(join ', ' "${versionAliases[@]}")"
  echo "GitCommit: ${commit}"
  echo "Directory: ${version}"
  echo
done
