#!/bin/bash

# Defaults...
BK_CACHE_COMPRESS=${BUILDKITE_PLUGIN_CACHE_TARBALL_COMPRESS:-false}
BK_TAR_ARGS=""
BK_TAR_ADDITIONAL_ARGS="--ignore-failed-read"
BK_TAR_EXTENSION="tar"
BK_TAR_EXTRACT_ARGS="-xf"
BK_BASE_DIR="/tmp"

if [ -n "$BUILDKITE_PLUGIN_CACHE_TARBALL_PATH" ]; then
  # Override /tmp with given param
  BK_BASE_DIR="$BUILDKITE_PLUGIN_CACHE_TARBALL_PATH"
fi

if [[ ! "$OSTYPE" == "darwin"* ]]; then
  shell_exec=$(
    exec 2>/dev/null
    readlink "/proc/$$/exe"
  )
  case "$shell_exec" in
  */busybox)
    BK_TAR_ADDITIONAL_ARGS=""
    ;;
  esac

  if [[ ! "${BK_CACHE_COMPRESS:-false}" =~ (false) ]]; then
    BK_TAR_ARGS="${BK_TAR_ADDITIONAL_ARGS} -zcf"
    BK_TAR_EXTENSION="tar.gz"
    BK_TAR_EXTRACT_ARGS="-xzf"
  else
    BK_TAR_ARGS="${BK_TAR_ADDITIONAL_ARGS} -cf"
  fi
else
  if [[ ! "${BK_CACHE_COMPRESS:-false}" =~ (false) ]]; then
    BK_TAR_ARGS="-zcf"
  else
    BK_TAR_ARGS="-cf"
  fi
fi

function restore() {
  CACHE_PREFIX="${BK_BASE_DIR}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"
  mkdir -p "${CACHE_PREFIX}/${BUILDKITE_PIPELINE_SLUG}"
  TAR_FILE="${CACHE_PREFIX}/${CACHE_KEY}.${BK_TAR_EXTENSION}"

  if [ -f "$TAR_FILE" ]; then
    cache_hit "tar://${TAR_FILE}"
    tar ${BK_TAR_EXTRACT_ARGS} "${TAR_FILE}" -C .
  fi
}

function cache() {
  CACHE_PREFIX="${BK_BASE_DIR}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"

  mkdir -p "${CACHE_PREFIX}"
  DAYS="${BUILDKITE_PLUGIN_CACHE_TARBALL_MAX:-}"
  if [ -n "$DAYS" ] && [ "$DAYS" -gt 0 ]; then
    echo "🗑️ Deleting backups older than ${DAYS} day(s)..."
    # On Linux, concurrent deletes race and cause a non-zero exit code. -ignore_readdir_race fixes this.
    # macOS handles this flag but it has no effect since bsdfind already returns zero in this case.
    find "${CACHE_PREFIX}" -type f -mtime +"${DAYS}" -exec rm -f {} \;
  fi

  if [ "${#paths[@]}" -eq 1 ]; then
    mkdir -p "${CACHE_PREFIX}"
    TAR_FILE="${CACHE_PREFIX}/${CACHE_KEY}.${BK_TAR_EXTENSION}"
    if [ ! -f "$TAR_FILE" ]; then
      tar $BK_TAR_ARGS "${TAR_FILE}" ${paths[*]}
    fi
  elif
    [ "${#paths[@]}" -gt 1 ]
  then
    mkdir -p "${CACHE_PREFIX}"
    TAR_FILE="${CACHE_PREFIX}/${CACHE_KEY}.${BK_TAR_EXTENSION}"
    if [ ! -f "$TAR_FILE" ]; then
      TMP_FILE="$(mktemp)"
      tar $BK_TAR_ARGS "${TMP_FILE}" ${paths[@]}
      mv -f "${TMP_FILE}" "${TAR_FILE}"
    fi
  fi
}
