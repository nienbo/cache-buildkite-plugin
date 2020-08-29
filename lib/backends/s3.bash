#!/bin/bash

function restore() {
  AWS_ARGS=""

  if [[ -n "${BUILDKITE_PLUGIN_CACHE_S3_PROFILE:-}" ]]; then
    AWS_ARGS="--profile ${BUILDKITE_PLUGIN_CACHE_S3_PROFILE}"
  fi

  TAR_FILE="${CACHE_KEY}.tar"
  BUCKET="${BUILDKITE_PLUGIN_CACHE_S3_BUCKET_NAME}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"
  TKEY="${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"

  aws s3api head-object --bucket "${BUILDKITE_PLUGIN_CACHE_S3_BUCKET_NAME}" --key "${TKEY}/${TAR_FILE}" || no_head=true

  if ${no_head:-false}; then
    cache_skip "s3://${BUCKET}/${TAR_FILE}"
  else
    cache_hit "s3://${BUCKET}/${TAR_FILE}"
    aws s3 cp "s3://${BUCKET}/${TAR_FILE}" . $AWS_ARGS
    tar -xf "${TAR_FILE}" -C .
  fi
}

