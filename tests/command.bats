#!/usr/bin/env bats

load "$BATS_PATH/load.bash"

# Uncomment to enable stub debugging
# export GIT_STUB_DEBUG=/dev/tty

@test "Pre-command restores cache with basic key" {
  
  stub aws \
   "aws s3 sync s3://my-bucket/my-org/my-pipeline/v1-cache-key/ . : echo sync cache"
  
  
  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET_NAME="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_CACHE_KEY="v1-cache-key"
  run "$PWD/hooks/pre-command"
  
  assert_success
  assert_output --partial "sync v1-cache-key"
  
  unset BUILDKITE_PLUGIN_CACHE_CACHE_KEY  
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET_NAME
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG
}

@test "Post-command syncs artifacts with a single path" {

  stub aws \
   "aws s3 sync Pods s3://my-bucket/my-org/my-pipeline/v1-cache-key/Pods : echo sync Pods"

  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET_NAME="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_CACHE_KEY="v1-cache-key"
  export BUILDKITE_PLUGIN_CACHE_PATHS="Pods"
  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "sync Pods"

  unset BUILDKITE_PLUGIN_CACHE_PATHS
  unset BUILDKITE_PLUGIN_CACHE_CACHE_KEY  
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET_NAME
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG
}
