#!/bin/bash

# Defaults...
BK_AWS_ARGS=""
BK_CACHE_COMPRESS=${BUILDKITE_PLUGIN_CACHE_S3_COMPRESS:-false}
BK_TAR_ARGS="--ignore-failed-read -cf"
BK_TAR_EXTENSION="tar"
BK_TAR_EXTRACT_ARGS="-xf"

if [[ ! "${BK_CACHE_COMPRESS:-false}" =~ (false) ]]; then
  BK_TAR_ARGS="--ignore-failed-read -zcf"
  BK_TAR_EXTENSION="tar.gz"
  BK_TAR_EXTRACT_ARGS="-xzf"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  if [[ ! "${BK_CACHE_COMPRESS:-false}" =~ (false) ]]; then
    BK_TAR_ARGS="-zcf"
  else
    BK_TAR_ARGS="-cf"
  fi
fi

if [[ -n "${BUILDKITE_PLUGIN_CACHE_S3_PROFILE:-}" ]]; then
  BK_AWS_ARGS="--profile ${BUILDKITE_PLUGIN_CACHE_S3_PROFILE}"
fi

if [[ -n "${BUILDKITE_PLUGIN_CACHE_S3_CLASS:-}" ]]; then
  BK_AWS_ARGS="${BK_AWS_ARGS} --storage-class '${BUILDKITE_PLUGIN_CACHE_S3_CLASS}'"
fi

if [[ -n "${BUILDKITE_PLUGIN_CACHE_S3_ARGS:-}" ]]; then
  BK_AWS_ARGS="${BK_AWS_ARGS} ${BUILDKITE_PLUGIN_CACHE_S3_ARGS}"
fi

function restore() {
  TAR_FILE="${CACHE_KEY}.${BK_TAR_EXTENSION}"
  BUCKET="${BUILDKITE_PLUGIN_CACHE_S3_BUCKET}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"
  TKEY="${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"

  aws s3api head-object --bucket "${BUILDKITE_PLUGIN_CACHE_S3_BUCKET}" --key "${TKEY}/${TAR_FILE}" || no_head=true

  if ${no_head:-false}; then
    cache_restore_skip "s3://${BUCKET}/${TAR_FILE}"
  else
    cache_hit "s3://${BUCKET}/${TAR_FILE}"
    aws s3 cp "s3://${BUCKET}/${TAR_FILE}" . $BK_AWS_ARGS
    tar ${BK_TAR_EXTRACT_ARGS} "${TAR_FILE}" -C .
  fi
}

function cache() {
  TAR_FILE="${CACHE_KEY}.${BK_TAR_EXTENSION}"
  BUCKET="${BUILDKITE_PLUGIN_CACHE_S3_BUCKET}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"

  if [ "${#paths[@]}" -eq 1 ]; then
    cache_locating "${paths[*]}"
    TAR_FILE="${CACHE_KEY}.${BK_TAR_EXTENSION}"
    if [ ! -f "$TAR_FILE" ]; then
      TMP_FILE="$(mktemp)"
      tar $BK_TAR_ARGS "${TMP_FILE}" "${paths[*]}"
      mv -f "${TMP_FILE}" "${TAR_FILE}"
    fi
    aws s3 cp "$TAR_FILE" "s3://${BUCKET}/${TAR_FILE}" $BK_AWS_ARGS
    rm -f "${TAR_FILE}"

  elif
    [ "${#paths[@]}" -gt 1 ]
  then
    cache_locating "${path}"
    TAR_FILE="${CACHE_KEY}.${BK_TAR_EXTENSION}"
    if [ ! -f "$TAR_FILE" ]; then
      TMP_FILE="$(mktemp)"
      tar $BK_TAR_ARGS "${TMP_FILE}" "${paths[@]}"
      mv -f "${TMP_FILE}" "${TAR_FILE}"
    fi
    aws s3 cp "${TAR_FILE}" "s3://${BUCKET}/${TAR_FILE}" $BK_AWS_ARGS
    rm -f "${TAR_FILE}"
  fi

}
