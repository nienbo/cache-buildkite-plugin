#!/bin/bash

# Defaults...
RSYNC_ARGS="--ignore-missing-args"
if [[ "$OSTYPE" == "darwin"* ]]; then
  RSYNC_ARGS=""
fi

function restore() {
  CACHE_PREFIX="${BUILDKITE_PLUGIN_CACHE_RSYNC_STORAGE}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"

  mkdir -p "${CACHE_PREFIX}/${CACHE_KEY}"
  rsync -a "$RSYNC_ARGS" "${CACHE_PREFIX}/${CACHE_KEY}/" .
}

function cache() {
  CACHE_PREFIX="${BUILDKITE_PLUGIN_CACHE_RSYNC_STORAGE}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"
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
