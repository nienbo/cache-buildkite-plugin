#!/bin/bash

function restore() {
  CACHE_PREFIX="${BUILDKITE_PLUGIN_CACHE_TARBALL_STORAGE}/${BUILDKITE_ORGANIZATION_SLUG}/${BUILDKITE_PIPELINE_SLUG}"
  mkdir -p "${CACHE_PREFIX}/${BUILDKITE_PIPELINE_SLUG}"
  TAR_FILE="${CACHE_PREFIX}/${CACHE_KEY}.tar"

  if [ -f "$TAR_FILE" ]; then
    cache_hit "tar://${TAR_FILE}"
    tar -xf "${TAR_FILE}" -C .
  fi
}
