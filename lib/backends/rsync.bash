#!/bin/bash

function restore() {
  RSYNC_ARGS="--ignore-missing-args"
  
  if [[ "$OSTYPE" == "darwin"* ]]; then
    RSYNC_ARGS=""
  fi

  CACHE_PREFIX="${BUILDKITE_PLUGIN_CACHE_RSYNC_STORAGE}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"

  mkdir -p "${CACHE_PREFIX}/${CACHE_KEY}"
  rsync -a "$RSYNC_ARGS" "${CACHE_PREFIX}/${CACHE_KEY}/" .
}
