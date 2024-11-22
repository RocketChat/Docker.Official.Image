function get_versions() {
  local versions=()
  local dirs=()

  if [ -n "$ZSH_VERSION" ]; then
    IFS=' ' read -rA dirs <<< "$(echo "./"*/)"
  else
    IFS=' ' read -ra dirs <<< "$(echo "./"*/)"
  fi

  for dir in "${dirs[@]}"; do
    if [ -f "${dir}/Dockerfile" ]; then
      versions+=("${dir#./}")
    fi
  done

  if [ ${#versions[@]} -gt 0 ]; then
    echo "${versions[@]%/}"
  fi
}

function get_full_version() {
  local version
  version=$1
  shift

  local default_dockerfile
  default_dockerfile="${version}/Dockerfile"

  grep -m1 'ENV RC_VERSION ' "${default_dockerfile}" | cut -d' ' -f3
}
