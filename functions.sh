#!/usr/bin/env bash
#
# Utlity functions

info() {
  printf "%s\\n" "$@"
}

fatal() {
  printf "**********\\n"
  printf "Fatal Error: %s\\n" "$@"
  printf "**********\\n"
  exit 1
}

# Get available versions for a given path
#
# If full or partial versions are provided then they are processed and
# validated. e.g. "6 chakracore" returns "6 chakracore/8" since it processed the
# chakracore entry and found it to be a fork rather than a complete version.
#
# The result is a list of valid versions.
function get_versions() {
  local versions=()

  for dir in *; do
    if [ -a "${dir}/Dockerfile" ]; then
      versions+=("${dir#./}")
    fi
  done

  if [ ${#versions[@]} -gt 0 ]; then
    echo "${versions[@]%/}"
  fi
}

function get_fork_name() {
  local version
  version=$1
  shift

  IFS='/' read -ra versionparts <<< "${version}"
  if [ ${#versionparts[@]} -gt 1 ]; then
    echo "${versionparts[0]}"
  fi
}

function get_full_version() {
  local version
  version=$1
  shift

  local default_dockerfile
  if [ -f "${version}/${default_variant}/Dockerfile" ]; then
    default_dockerfile="${version}/${default_variant}/Dockerfile"
  else
    default_dockerfile="${version}/Dockerfile"
  fi

  grep -m1 'ENV RC_VERSION ' "${default_dockerfile}" | cut -d' ' -f3
}

function get_major_minor_version() {
  local version
  version=$1
  shift

  local fullversion
  fullversion=$(get_full_version "${version}")

  echo "$(echo "${fullversion}" | cut -d'.' -f1).$(echo "${fullversion}" | cut -d'.' -f2)"
}

function get_tag() {
  local version
  version=$1
  shift

  local versiontype
  versiontype=${1:-full}
  shift

  local tagversion
  if [ "${versiontype}" = full ]; then
    tagversion=$(get_full_version "${version}")
  elif [ "${versiontype}" = majorminor ]; then
    tagversion=$(get_major_minor_version "${version}")
  fi

  local tagparts
  IFS=' ' read -ra tagparts <<< "$(get_fork_name "${version}") ${tagversion}"
  IFS='-'
  echo "${tagparts[*]}"
  unset IFS
}

function sort_versions() {
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
