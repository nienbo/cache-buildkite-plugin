#!/bin/bash

# This file will contain functions for Rsync Cache, Tarball Cache, S3 Cache and Google Cloud Cache.

# Expand templates (e.g. {{ checksum 'Gemfile.lock' }})
# If a template cannot be expanded, the function returns a failure code.
# Args:
#   - CACHE_KEY: String that may or may not contain templates.
# Returns:
#   - String
function expand_templates() {
  CACHE_KEY="$1"
  HASHER_BIN="sha1sum"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    HASHER_BIN="shasum"
  fi

  while [[ "$CACHE_KEY" =~ (.*)\{\{\ *(.*)\ *\}\}(.*) ]]; do
    TEMPLATE_VALUE="${BASH_REMATCH[2]}"
    EXPANDED_VALUE=""
    case $TEMPLATE_VALUE in
    "checksum "*)
      TARGET="$(echo -e "${TEMPLATE_VALUE/"checksum"/""}" | tr -d \' | tr -d \" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      EXPANDED_VALUE=$(find "$TARGET" -type f -exec $HASHER_BIN {} \; | sort -k 2 | $HASHER_BIN | awk '{print $1}')
      ;;
    "date "*)
      DATE_FMT="$(echo -e "${TEMPLATE_VALUE/"date"/""}" | tr -d \' | tr -d \" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      EXPANDED_VALUE=$(date "${DATE_FMT}")
      ;;
    "env."*)
      ENV_VAR_NAME="$(echo -e "${TEMPLATE_VALUE/"env."/""}" | tr -d \' | tr -d \" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      EXPANDED_VALUE="${!ENV_VAR_NAME}"
      ;;
    "git.branch"*)
      BRANCH="${BUILDKITE_BRANCH}"
      EXPANDED_VALUE="${BRANCH//\//_}"
      ;;
    "git.commit"*)
      EXPANDED_VALUE="${BUILDKITE_COMMIT}"
      ;;
    "id"*)
      EXPANDED_VALUE="${BK_CACHE_ID}"
      ;;
    "runner.os"*)
      case $OSTYPE in
      "linux-gnu"* | "freebsd"*)
        OS="Linux"
        ;;
      "darwin"*)
        OS="macOS"
        ;;
      "cygwin" | "msys" | "win32" | "mingw"*)
        OS="Windows"
        ;;
      *)
        OS="Generic"
        ;;
      esac
      EXPANDED_VALUE="${OS}"
      ;;
    *)
      echo >&2 "Invalid template expression: $TEMPLATE_VALUE"
      return 1
      ;;
    esac
    CACHE_KEY="${BASH_REMATCH[1]}${EXPANDED_VALUE}${BASH_REMATCH[3]}"
  done

  echo "$CACHE_KEY"
}

function cache_hit() {
  echo -e "${BK_LOG_PREFIX}🔥 Cache hit: $1"
}

function cache_restore_skip() {
  echo -e "${BK_LOG_PREFIX}🚨 Cache restore is skipped because $1 does not exist"
}

function error() {
  echo -e "${BK_LOG_PREFIX}🚨 $1"
}

function info() {
  echo -e "${BK_LOG_PREFIX}ℹ️ $1"
}

function source_locating() {
  echo -e "${BK_LOG_PREFIX}🔍 Locating source: $1"
}

function cache_locating() {
  echo -e "${BK_LOG_PREFIX}🔍 Locating cache: $1"
}

# Value to be used as the pipeline slug
# Returns:
#   - String
function pipeline_slug() {
  echo "${BUILDKITE_PLUGIN_CACHE_PIPELINE_SLUG_OVERRIDE:-${BUILDKITE_PIPELINE_SLUG}}"
}
