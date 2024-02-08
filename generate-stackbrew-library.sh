#!/bin/bash
set -eu

declare -A aliases=(
  [6.6]='6 latest'
)

cd "$(cd "${0%/*}" && pwd -P)"

sort_versions() {
  local versions=("$@")
  local sorted
  local lines
  local line

  IFS=$'\n'
  lines="${versions[*]}"
  unset IFS

  while IFS='' read -r line; do
    sorted+=("${line}")
  done <<< "$(echo "${lines}" | grep "^[0-9]" | sort -r)"

  while IFS='' read -r line; do
    sorted+=("${line}")
  done <<< "$(echo "${lines}" | grep -v "^[0-9]" | sort -r)"

  echo "${sorted[@]}"
}

versions=( */ )
IFS=' ' read -ra versions <<< "$(sort_versions "${versions[@]%/}")"

# get the most recent commit which modified any of "$@"
fileCommit() {
  git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
  local dir="$1"; shift
  (
    cd "$dir"
    fileCommit \
      Dockerfile \
      $(git show HEAD:./Dockerfile | awk '
        toupper($1) == "COPY" {
          for (i = 2; i < NF; i++) {
            print $i
          }
        }
      ')
  )
}

self="$(basename "${BASH_SOURCE[0]}")"
url='https://github.com/RocketChat/Docker.Official.Image'

echo "# this file is generated via ${url}/blob/$(fileCommit "${self}")/${self}"
echo
echo "Maintainers: Rocket.Chat Image Team <buildmaster@rocket.chat> (@RocketChat)"
echo "GitRepo: ${url}.git"
echo

# prints "$2$1$3$1...$N"
join() {
  local sep="$1"; shift
  local out; printf -v out "${sep//%/%%}%s" "$@"
  echo "${out#$sep}"
}

for version in "${versions[@]}"; do
  # Skip "docs" and other non-docker directories
  [ -f "${version}/Dockerfile" ] || continue

  commit="$(dirCommit "$version")"

  fullVersion="$(git show "$commit":"$version/Dockerfile" | awk '$1 == "ENV" && $2 == "RC_VERSION" { gsub(/~/, "-", $3); print $3; exit }')"

  versionAliases=( $fullVersion )

  versionAliases+=(
    $version
    ${aliases[$version]:-}
  )

  echo "Tags: $(join ', ' "${versionAliases[@]}")"
  echo "GitCommit: ${commit}"
  echo "Directory: ${version}"
  echo
done
