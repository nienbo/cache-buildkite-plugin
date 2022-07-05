#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"
}

shared_lib="$PWD/lib/shared.bash"

@test "expand_templates expands an environment variable" {
  source $shared_lib

  export FOO=bar 
  cache_key="v1-{{ env.FOO }}-cache"

  run expand_templates "${cache_key}"

  assert_success
  assert_output "v1-bar-cache"
}

@test "expand_templates produces output for missing environment variable" {
  source $shared_lib

  cache_key="v1-{{ env.BAZ }}-cache"

  run expand_templates "${cache_key}"

  assert_success
  assert_output "v1--cache"
}
