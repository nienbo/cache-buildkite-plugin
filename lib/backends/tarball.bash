#!/bin/bash

# Defaults...
BK_CACHE_COMPRESS=${BUILDKITE_PLUGIN_CACHE_COMPRESS:-false}
BK_TAR_ARGS=()
BK_TAR_ADDITIONAL_ARGS="--ignore-failed-read"
BK_TAR_EXTENSION="tar"
BK_TAR_EXTRACT_ARGS="-xf"
BK_BASE_DIR="/tmp"

if [ -n "${BUILDKITE_PLUGIN_CACHE_TARBALL_PATH:-}" ]; then
  # Override /tmp with given param
  BK_BASE_DIR="${BUILDKITE_PLUGIN_CACHE_TARBALL_PATH}"
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
    number_re='^[0-9]+$'
    if [[ ${BK_CACHE_COMPRESS} =~ $number_re ]]; then
      BK_TAR_ARGS=("$BK_TAR_ADDITIONAL_ARGS" --use-compress-program "gzip -$BK_CACHE_COMPRESS" -cf)
    else
      BK_TAR_ARGS=("$BK_TAR_ADDITIONAL_ARGS" -zcf)
    fi
    BK_TAR_EXTENSION="tar.gz"
    BK_TAR_EXTRACT_ARGS="-xzf"
  else
    BK_TAR_ARGS=("$BK_TAR_ADDITIONAL_ARGS" -cf)
  fi
else
  if [[ ! "${BK_CACHE_COMPRESS:-false}" =~ (false) ]]; then
    BK_TAR_ARGS=(-zcf)
  else
    BK_TAR_ARGS=(-cf)
  fi
fi

function restore() {
  CACHE_PREFIX="${BK_BASE_DIR}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"
  mkdir -p "${CACHE_PREFIX}/${BUILDKITE_PIPELINE_SLUG}"
  TAR_FILE="${CACHE_PREFIX}/${CACHE_KEY}.${BK_TAR_EXTENSION}"
  BK_TAR_FOUND=false

  if [ -f "$TAR_FILE" ]; then
    BK_TAR_FOUND=true
    cache_hit "tar://${TAR_FILE}"
  else
    # Now, lets try one of the restore keys...
    if [ "${#keys[@]}" -gt 0 ]; then
      for key in "${keys[@]}"; do
        key="$(expand_templates "${key}")"
        echo -e "${BK_LOG_PREFIX}🔍 Looking using restore-key: ${key}"
        search_for="${CACHE_PREFIX}/${key}*"
        PKEY=""
        for f in $search_for; do
          [[ -d $f ]] && continue
          [[ $f -nt $PKEY ]] && PKEY=$f
        done
        PKEY="${PKEY%\"}"
        PKEY="${PKEY#\"}"
        if [ "${PKEY}" == "" ]; then
          continue
        else
          # Actually, we can use PKEY as-is. But we still need the only last part of the key.
          TAR_FILE="${PKEY##*/}"
          BK_TAR_FOUND=true
          cache_hit "tar://${TAR_FILE} by using restore key: ${key}"
          break
        fi
      done
    fi
  fi

  if [[ ! "${BK_TAR_FOUND}" =~ (false) ]]; then
    tar ${BK_TAR_EXTRACT_ARGS} "${CACHE_PREFIX}/${TAR_FILE}" -C .
  else
    cache_restore_skip "tar://${TAR_FILE}"
  fi
}

function cache() {
  CACHE_PREFIX="${BK_BASE_DIR}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"

  mkdir -p "${CACHE_PREFIX}"
  DAYS="${BUILDKITE_PLUGIN_CACHE_TARBALL_MAX:-}"
  if [ -n "$DAYS" ] && [ "$DAYS" -gt 0 ]; then
    echo -e "${BK_LOG_PREFIX}🗑️ Deleting backups older than ${DAYS} day(s)..."
    # On Linux, concurrent deletes race and cause a non-zero exit code. -ignore_readdir_race fixes this.
    # macOS handles this flag but it has no effect since bsdfind already returns zero in this case.
    find "${CACHE_PREFIX}" -type f -mtime +"${DAYS}" -exec rm -f {} \;
  fi

  TAR_TARGETS=""

  if [ "${#paths[@]}" -eq 1 ]; then
    TAR_TARGETS="${paths[*]}"
  elif
    [ "${#paths[@]}" -gt 1 ]
  then
    TAR_TARGETS="${paths[@]}"
  fi

  cache_locating "${TAR_TARGETS}"
  mkdir -p "${CACHE_PREFIX}"
  TAR_FILE="${CACHE_PREFIX}/${CACHE_KEY}.${BK_TAR_EXTENSION}"
  if [ ! -f "$TAR_FILE" ]; then
    TMP_FILE="$(mktemp)"
    tar "${BK_TAR_ARGS[@]}" "${TMP_FILE}" ${TAR_TARGETS}
    mv -f "${TMP_FILE}" "${TAR_FILE}"
  fi
}
