#!/bin/bash

# Defaults...
RSYNC_ARGS="--ignore-missing-args"
BK_BASE_DIR="/tmp"

if [[ "$OSTYPE" == "darwin"* ]]; then
  RSYNC_ARGS=""
fi

if [ -n "${BUILDKITE_PLUGIN_CACHE_RSYNC_PATH:-}" ]; then
  # Override /tmp with given param
  BK_BASE_DIR="${BUILDKITE_PLUGIN_CACHE_RSYNC_PATH}"
fi

function restore() {
  CACHE_PREFIX="${BK_BASE_DIR}/${BUILDKITE_ORGANIZATION_SLUG}/$(pipeline_slug)"

  mkdir -p "${CACHE_PREFIX}/${CACHE_KEY}"
  rsync -a "$RSYNC_ARGS" "${CACHE_PREFIX}/${CACHE_KEY}/" .
}

function cache() {
  CACHE_PREFIX="${BK_BASE_DIR}/${BUILDKITE_ORGANIZATION_SLUG}/$(pipeline_slug)"
  mkdir -p "${CACHE_PREFIX}/${CACHE_KEY}/"

  if [ "${#paths[@]}" -eq 1 ]; then
    mkdir -p "${CACHE_PREFIX}/${CACHE_KEY}/${paths[*]}"
    rsync -a "$RSYNC_ARGS" --delete "${paths[*]}/" "${CACHE_PREFIX}/${CACHE_KEY}/${paths[*]}/"
  elif
    [ "${#paths[@]}" -gt 1 ]
  then
    for path in "${paths[@]}"; do
      mkdir -p "${CACHE_PREFIX}/${CACHE_KEY}/${path}"
      rsync -a "$RSYNC_ARGS" --delete "${path}/" "${CACHE_PREFIX}/${CACHE_KEY}/${path}/"
    done
  fi
}
