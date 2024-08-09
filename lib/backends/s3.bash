#!/bin/bash

# Defaults...
BK_DEFAULT_AWS_ARGS=""
BK_CUSTOM_AWS_ARGS=""
BK_CACHE_COMPRESS=${BUILDKITE_PLUGIN_CACHE_COMPRESS:-false}
BK_CACHE_COMPRESS_PROGRAM=${BUILDKITE_PLUGIN_CACHE_COMPRESS_PROGRAM:-gzip}
BK_CACHE_SAVE_CACHE=${BUILDKITE_PLUGIN_CACHE_S3_SAVE_CACHE:-false}
BK_ALWAYS_CACHE=${BUILDKITE_PLUGIN_CACHE_ALWAYS:-false}
BK_CACHE_LOCAL_PATH="/tmp"
BK_TAR_ARGS=()
BK_TAR_ADDITIONAL_ARGS="--ignore-failed-read"
BK_TAR_EXTENSION="tar"
BK_TAR_EXTRACT_ARGS="-xf"

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
      BK_TAR_ARGS=("$BK_TAR_ADDITIONAL_ARGS" --use-compress-program "$BK_CACHE_COMPRESS_PROGRAM -$BK_CACHE_COMPRESS" -cf)
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

if [[ -n "${BUILDKITE_PLUGIN_CACHE_S3_PROFILE:-}" ]]; then
  BK_DEFAULT_AWS_ARGS="--profile ${BUILDKITE_PLUGIN_CACHE_S3_PROFILE}"
fi

if [[ -n "${BUILDKITE_PLUGIN_CACHE_S3_CLASS:-}" ]]; then
  BK_DEFAULT_AWS_ARGS="${BK_DEFAULT_AWS_ARGS} --storage-class '${BUILDKITE_PLUGIN_CACHE_S3_CLASS}'"
fi

if [[ -n "${BUILDKITE_PLUGIN_CACHE_S3_ENDPOINT:-}" ]]; then
  BK_DEFAULT_AWS_ARGS="${BK_DEFAULT_AWS_ARGS} --endpoint-url ${BUILDKITE_PLUGIN_CACHE_S3_ENDPOINT}"
fi

if [[ -n "${BUILDKITE_PLUGIN_CACHE_S3_REGION:-}" ]]; then
  BK_DEFAULT_AWS_ARGS="${BK_DEFAULT_AWS_ARGS} --region ${BUILDKITE_PLUGIN_CACHE_S3_REGION}"
fi

BK_CUSTOM_AWS_ARGS="${BK_DEFAULT_AWS_ARGS}"

if [[ -n "${BUILDKITE_PLUGIN_CACHE_S3_ARGS:-}" ]]; then
  BK_CUSTOM_AWS_ARGS="${BK_CUSTOM_AWS_ARGS} ${BUILDKITE_PLUGIN_CACHE_S3_ARGS}"
fi

function restore() {
  TAR_FILE="${CACHE_KEY}.${BK_TAR_EXTENSION}"
  TKEY="${BUILDKITE_ORGANIZATION_SLUG}/$(pipeline_slug)"
  BUCKET="${BUILDKITE_PLUGIN_CACHE_S3_BUCKET}/${TKEY}"
  BK_AWS_FOUND=false

  # Check if prefere local is true and if tar file exists in tmp dir
  if [ "${BK_CACHE_SAVE_CACHE}" == "true" ] && [ -f "${BK_CACHE_LOCAL_PATH}/${TAR_FILE}" ]; then
    echo -e "${BK_LOG_PREFIX}:file_cabinet: Using previously downloaded file ${BK_CACHE_LOCAL_PATH}/${TAR_FILE} since local is prefered."
    if tar ${BK_TAR_EXTRACT_ARGS} "${BK_CACHE_LOCAL_PATH}/${TAR_FILE}" -C . ; then
        return
    fi
    echo -e "${BK_LOG_PREFIX}:file_cabinet: Ignoring corrupted previously downloaded file ${BK_CACHE_LOCAL_PATH}/${TAR_FILE}."
  fi

  aws s3api head-object --bucket "${BUILDKITE_PLUGIN_CACHE_S3_BUCKET}" --key "${TKEY}/${TAR_FILE}" ${BK_DEFAULT_AWS_ARGS} || no_head=true

  if ${no_head:-false}; then
    # Check `jq` first
    if command -v jq &>/dev/null; then
      # Now, lets try one of the restore keys...
      if [ "${#keys[@]}" -gt 0 ]; then
        for key in "${keys[@]}"; do
          key="$(expand_templates "${key}")"
          echo -e "${BK_LOG_PREFIX}🔍 Looking using restore-key: ${key}"
          PKEY=$(aws s3api list-objects --bucket "${BUILDKITE_PLUGIN_CACHE_S3_BUCKET}" ${BK_DEFAULT_AWS_ARGS} --prefix="${TKEY}/${key}" --query 'Contents[].{Key: Key, LastModified: LastModified}' | jq 'try(. |= sort_by(.LastModified)  |  first(reverse[]) | .["Key"]) catch "NULL"')
          PKEY="${PKEY%\"}"
          PKEY="${PKEY#\"}"
          if [ "${PKEY}" == "NULL" ]; then
            continue
          else
            # Actually, we can use PKEY as-is. But we still need the only last part of the key.
            TAR_FILE="${PKEY##*/}"
            BK_AWS_FOUND=true
            cache_hit "s3://${BUCKET}/${TAR_FILE} by using restore key: ${key}"
            break
          fi
        done
      fi
    else
      error "'jq' command not found. 'restore-keys' will be discarded."
    fi
  else
    BK_AWS_FOUND=true
    cache_hit "s3://${BUCKET}/${TAR_FILE}"
  fi

  if [[ ! "${BK_AWS_FOUND}" =~ (false) ]]; then
    TMP_FILE="$(mktemp)"
    aws s3 cp ${BK_CUSTOM_AWS_ARGS} "s3://${BUCKET}/${TAR_FILE}" "${TMP_FILE}"  || s3_download_failed=true
    if ${s3_download_failed:-false}; then
      echo -e "S3 download failed, soft failing and skipping cache restore..."
      return 0
    else
      mv -f "${TMP_FILE}" "${TAR_FILE}"
    fi

    [ "${BK_CACHE_SAVE_CACHE}" == "true" ] && cp "${TAR_FILE}" "${BK_CACHE_LOCAL_PATH}/${TAR_FILE}"
    tar ${BK_TAR_EXTRACT_ARGS} "${TAR_FILE}" -C .
  else
    cache_restore_skip "s3://${BUCKET}/${TAR_FILE}"
  fi
}

function cache() {
  TAR_FILE="${CACHE_KEY}.${BK_TAR_EXTENSION}"
  BUCKET="${BUILDKITE_PLUGIN_CACHE_S3_BUCKET}/${BUILDKITE_ORGANIZATION_SLUG}/$(pipeline_slug)"
  TAR_TARGETS=""

  if [ "${#paths[@]}" -eq 1 ]; then
    TAR_TARGETS="${paths[*]}"
  elif
    [ "${#paths[@]}" -gt 1 ]
  then
    TAR_TARGETS="${paths[@]}"
  fi

  cache_locating "${TAR_TARGETS}"
  TAR_FILE="${CACHE_KEY}.${BK_TAR_EXTENSION}"

  if [ $BK_ALWAYS_CACHE == "true" ]; then
    echo -e "${BK_LOG_PREFIX}:file_cabinet::close: Removing previously found cache ${TAR_FILE} since always is true."
    rm -f "${TAR_FILE}"
  fi

  if [ ! -f "$TAR_FILE" ]; then
    TMP_FILE="$(mktemp)"
    tar "${BK_TAR_ARGS[@]}" "${TMP_FILE}" ${TAR_TARGETS}
    mv -f "${TMP_FILE}" "${TAR_FILE}"

    if ! tar tf "${TAR_FILE}" &> /dev/null; then
      rm -rf "${TAR_FILE}"
      tar "${BK_TAR_ARGS[@]}" "${TMP_FILE}" ${TAR_TARGETS}
      mv -f "${TMP_FILE}" "${TAR_FILE}"
    fi
    if ! tar tf "${TAR_FILE}" &> /dev/null; then
      error "Error while packaging cache"
    else
      aws s3 cp ${BK_CUSTOM_AWS_ARGS} "${TAR_FILE}" "s3://${BUCKET}/${TAR_FILE}"
    fi
  fi
  rm -f "${TAR_FILE}"
}
