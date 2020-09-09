#!/bin/bash

# This file will contain functions for Rsync Cache, Tarball Cache, S3 Cache and Google Cloud Cache.

# Expand templates (e.g. {{ checksum 'Gemfile.lock' }})
# If a template cannot be expanded, the function returns a failure code.
# Args:
#   - CACHE_KEY: String that may or may not contain templates.
# Returns:
#   - String
function expand_templates {
  CACHE_KEY="$1"
  HASHER_BIN="sha1sum"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    HASHER_BIN="shasum"
  fi

  while [[ "$CACHE_KEY" =~ (.*)\{\{\ *(.*)\ *\}\}(.*) ]]; do
    TEMPLATE_VALUE="${BASH_REMATCH[2]}"
    EXPANDED_VALUE=""
    if [[ $TEMPLATE_VALUE == "checksum "* ]]; then
      TARGET="$(echo -e "${TEMPLATE_VALUE/"checksum"/""}" | tr -d \' | tr -d \" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      EXPANDED_VALUE=$(find "$TARGET" -type f -exec $HASHER_BIN {} \; | sort -k 2 | $HASHER_BIN | awk '{print $1}')
    else
      >&2 echo "Invalid template expression: $TEMPLATE_VALUE"; return 1
    fi
    CACHE_KEY="${BASH_REMATCH[1]}${EXPANDED_VALUE}${BASH_REMATCH[3]}"
  done

  echo "$CACHE_KEY"
}


function cache_hit {
  echo "🔥 Cache hit: $1"
}

function cache_restore_skip {
  echo "🚨 Cache restore is skipped because $1 does not exist"
}

function cache_locating {
  echo "🔍 Locating cache: $1"
}
