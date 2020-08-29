#!/bin/bash

# Defaults...
AWS_ARGS=""

if [[ -n "${BUILDKITE_PLUGIN_CACHE_S3_PROFILE:-}" ]]; then
  AWS_ARGS="--profile ${BUILDKITE_PLUGIN_CACHE_S3_PROFILE}"
fi

function restore() {
  TAR_FILE="${CACHE_KEY}.tar"
  BUCKET="${BUILDKITE_PLUGIN_CACHE_S3_BUCKET}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"
  TKEY="${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"

  aws s3api head-object --bucket "${BUILDKITE_PLUGIN_CACHE_S3_BUCKET}" --key "${TKEY}/${TAR_FILE}" || no_head=true

  if ${no_head:-false}; then
    cache_skip "s3://${BUCKET}/${TAR_FILE}"
  else
    cache_hit "s3://${BUCKET}/${TAR_FILE}"
    aws s3 cp "s3://${BUCKET}/${TAR_FILE}" . $AWS_ARGS
    tar -xf "${TAR_FILE}" -C .
  fi
}

function cache() {
  TAR_FILE="${CACHE_KEY}.tar"
  BUCKET="${BUILDKITE_PLUGIN_CACHE_S3_BUCKET}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"

  if [ "${#paths[@]}" -eq 1 ]; then
    echo "🔍 Locating cache on S3: ${paths[*]}"
    TAR_FILE="${CACHE_KEY}.tar"
    if [ ! -f "$TAR_FILE" ]; then
      TMP_FILE="$(mktemp)"
      tar $TAR_ARGS "${TMP_FILE}" "${paths[*]}"
      mv -f "${TMP_FILE}" "${TAR_FILE}"
    fi
    aws s3 cp "$TAR_FILE" "s3://${BUCKET}/${TAR_FILE}" $AWS_ARGS
    rm -f "${TAR_FILE}"

  elif
    [ "${#paths[@]}" -gt 1 ]
  then
    echo "🔍 Locating cache on S3: ${path}"
    TAR_FILE="${CACHE_KEY}.tar"
    if [ ! -f "$TAR_FILE" ]; then
      TMP_FILE="$(mktemp)"
      tar $TAR_ARGS "${TMP_FILE}" "${paths[@]}"
      mv -f "${TMP_FILE}" "${TAR_FILE}"
    fi
    aws s3 cp "${TAR_FILE}" "s3://${BUCKET}/${TAR_FILE}" $AWS_ARGS
    rm -f "${TAR_FILE}"
  fi

}
