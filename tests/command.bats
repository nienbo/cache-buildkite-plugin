#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"

  # Uncomment to enable stub debugging
  # export AWS_STUB_DEBUG=/dev/tty
  # export GIT_STUB_DEBUG=/dev/tty
  # export TAR_STUB_DEBUG=/dev/tty
}

@test "Pre-command restores cache with basic key" {
  stub mktemp \
   " : echo '/tmp/tempfile'"

  stub mv \
    "-f /tmp/tempfile v1-cache-key.tar : true"

  stub aws \
   "s3api head-object --bucket my-bucket --key 'my-org/my-pipeline/v1-cache-key.tar' --profile my-profile : true" \
   "s3 cp --profile my-profile s3://my-bucket/my-org/my-pipeline/v1-cache-key.tar /tmp/tempfile : echo Copied from S3"

  stub tar \
   "-xf v1-cache-key.tar -C . : echo Extracted tar archive"

  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_BACKEND="s3"
  export BUILDKITE_PLUGIN_CACHE_KEY="v1-cache-key"

  run "$PWD/hooks/pre-command"
  assert_success
  assert_output --partial "Copied from S3"
  refute_output --partial "Using previously downloaded file"
  assert_output --partial "Extracted tar archive"

  unset BUILDKITE_PLUGIN_CACHE_KEY
  unset BUILDKITE_PLUGIN_CACHE_BACKEND
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG

  unstub aws
  unstub tar
  unstub mv
  unstub mktemp
}

@test "Pre-command restores S3 backed cache using local file" {
  RANDOM_NUM=$(echo $RANDOM)

  stub tar \
   "-xf /tmp/v1-local-cache-key-${RANDOM_NUM}.tar -C . : echo Extracted tar archive"

  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_S3_SAVE_CACHE="true"
  export BUILDKITE_PLUGIN_CACHE_BACKEND="s3"
  export BUILDKITE_PLUGIN_CACHE_KEY="v1-local-cache-key-${RANDOM_NUM}"

  touch "/tmp/${BUILDKITE_PLUGIN_CACHE_KEY}.tar"

  run "$PWD/hooks/pre-command"
  assert_success
  refute_output --partial "Copied from S3"
  assert_output --partial "Using previously downloaded file"
  assert_output --partial "Extracted tar archive"

  unset BUILDKITE_PLUGIN_CACHE_KEY
  unset BUILDKITE_PLUGIN_CACHE_BACKEND
  unset BUILDKITE_PLUGIN_CACHE_S3_SAVE_CACHE
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG

  unstub tar
}

@test "Post-command syncs artifacts with a single path" {

  stub mktemp \
   " : echo '/tmp/tempfile'"
  stub tar \
   "--ignore-failed-read -cf /tmp/tempfile Pods : echo Created tar archive"
  stub mv \
    "-f /tmp/tempfile v1-cache-key.tar : true"
  stub aws \
   "s3 cp --profile my-profile v1-cache-key.tar s3://my-bucket/my-org/my-pipeline/v1-cache-key.tar : echo Copied to S3"

  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_BACKEND="s3"
  export BUILDKITE_PLUGIN_CACHE_KEY="v1-cache-key"
  export BUILDKITE_PLUGIN_CACHE_PATHS="Pods"
  export BUILDKITE_COMMAND_EXIT_STATUS="0"

  run "$PWD/hooks/post-command"
  assert_success
  assert_output --partial "Created tar archive"
  assert_output --partial "Copied to S3"

  unset BUILDKITE_COMMAND_EXIT_STATUS
  unset BUILDKITE_PLUGIN_CACHE_PATHS
  unset BUILDKITE_PLUGIN_CACHE_BACKEND
  unset BUILDKITE_PLUGIN_CACHE_KEY
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG

  unstub mktemp
  unstub tar
  unstub mv
  unstub aws
}

@test "Cache key template evaluation on file" {
  CHECKSUM=355831032f586e782b45744f2ed79316cc830244

  stub mktemp \
   " : echo '/tmp/tempfile'"

  stub mv \
    "-f /tmp/tempfile v1-cache-key-${CHECKSUM}.tar : true"

  stub aws \
   "s3api head-object --bucket my-bucket --key 'my-org/my-pipeline/v1-cache-key-${CHECKSUM}.tar' --profile my-profile : true" \
   "s3 cp --profile my-profile s3://my-bucket/my-org/my-pipeline/v1-cache-key-${CHECKSUM}.tar /tmp/tempfile : echo Copied from S3"

  stub tar \
   "-xf v1-cache-key-${CHECKSUM}.tar -C . : echo Extracted tar archive"

  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_BACKEND="s3"
  export BUILDKITE_PLUGIN_CACHE_KEY="v1-cache-key-{{ checksum 'tests/data/checksum/foo.lock' }}"

  run "$PWD/hooks/pre-command"
  assert_success
  assert_output --partial "Copied from S3"
  assert_output --partial "Extracted tar archive"

  unset BUILDKITE_PLUGIN_CACHE_KEY
  unset BUILDKITE_PLUGIN_CACHE_BACKEND
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG

  unstub mktemp
  unstub mv
  unstub aws
  unstub tar
}

@test "Cache key template evaluation on dir" {
  CHECKSUM=4cfa4e590847976f26d761074e355e4d95fa8107

  stub mktemp \
   " : echo '/tmp/tempfile'"

  stub mv \
    "-f /tmp/tempfile v1-cache-key-${CHECKSUM}.tar : true"

  stub aws \
   "s3api head-object --bucket my-bucket --key 'my-org/my-pipeline/v1-cache-key-${CHECKSUM}.tar' --profile my-profile : true" \
   "s3 cp --profile my-profile s3://my-bucket/my-org/my-pipeline/v1-cache-key-${CHECKSUM}.tar /tmp/tempfile : echo Copied from S3"

  stub tar \
   "-xf v1-cache-key-${CHECKSUM}.tar -C . : echo Extracted tar archive"

  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_BACKEND="s3"
  export BUILDKITE_PLUGIN_CACHE_KEY="v1-cache-key-{{ checksum 'tests/data/checksum' }}"

  run "$PWD/hooks/pre-command"
  assert_success
  assert_output --partial "Copied from S3"
  assert_output --partial "Extracted tar archive"

  unset BUILDKITE_PLUGIN_CACHE_KEY
  unset BUILDKITE_PLUGIN_CACHE_BACKEND
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG

  unstub mktemp
  unstub mv
  unstub aws
  unstub tar
}

@test "Cache key multi-template evaluation" {
  CHECKSUMS=355831032f586e782b45744f2ed79316cc830244-241bc31c8ddc004c48e6d88d7fa51ee981b8ce51

  stub mktemp \
   " : echo '/tmp/tempfile'"

  stub mv \
    "-f /tmp/tempfile v1-cache-key-${CHECKSUMS}.tar : true"

  stub aws \
   "s3api head-object --bucket my-bucket --key 'my-org/my-pipeline/v1-cache-key-${CHECKSUMS}.tar' --profile my-profile : true" \
   "s3 cp --profile my-profile s3://my-bucket/my-org/my-pipeline/v1-cache-key-${CHECKSUMS}.tar /tmp/tempfile : echo Copied from S3"

  stub tar \
   "-xf v1-cache-key-${CHECKSUMS}.tar -C . : echo Extracted tar archive"

  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_BACKEND="s3"
  export BUILDKITE_PLUGIN_CACHE_KEY="v1-cache-key-{{ checksum 'tests/data/checksum/foo.lock' }}-{{ checksum 'tests/data/checksum/bar.lock' }}"

  run "$PWD/hooks/pre-command"
  assert_success
  assert_output --partial "Copied from S3"
  assert_output --partial "Extracted tar archive"

  unset BUILDKITE_PLUGIN_CACHE_KEY
  unset BUILDKITE_PLUGIN_CACHE_BACKEND
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG

  unstub mktemp
  unstub mv
  unstub aws
  unstub tar
}

@test "Cache key template evaluation in middle of key" {
  CHECKSUM=355831032f586e782b45744f2ed79316cc830244

  stub mktemp \
   " : echo '/tmp/tempfile'"

  stub mv \
    "-f /tmp/tempfile v1-cache-${CHECKSUM}-key.tar : true"

  stub aws \
   "s3api head-object --bucket my-bucket --key 'my-org/my-pipeline/v1-cache-$CHECKSUM-key.tar' --profile my-profile : true" \
   "s3 cp --profile my-profile s3://my-bucket/my-org/my-pipeline/v1-cache-$CHECKSUM-key.tar /tmp/tempfile : echo Copied from S3"

  stub tar \
   "-xf v1-cache-$CHECKSUM-key.tar -C . : echo Extracted tar archive"

  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_BACKEND="s3"
  export BUILDKITE_PLUGIN_CACHE_KEY="v1-cache-{{ checksum 'tests/data/checksum/foo.lock' }}-key"

  run "$PWD/hooks/pre-command"
  assert_success
  assert_output --partial "Copied from S3"
  assert_output --partial "Extracted tar archive"

  unset BUILDKITE_PLUGIN_CACHE_KEY
  unset BUILDKITE_PLUGIN_CACHE_BACKEND
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG

  unstub mktemp
  unstub mv
  unstub aws
  unstub tar
}

@test "Cache key failed template evaluation fails" {

  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_BACKEND="s3"
  # Deliberately misspell checksum as cheksum.
  export BUILDKITE_PLUGIN_CACHE_KEY="v1-cache-key-{{ cheksum 'tests/data/checksum/foo.lock' }}"

  run "$PWD/hooks/pre-command"
  assert_failure
  assert_output --partial "Invalid template expression: cheksum"

  unset BUILDKITE_PLUGIN_CACHE_KEY
  unset BUILDKITE_PLUGIN_CACHE_BACKEND
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG
}

@test "S3 arguments are passed through to copy command" {

  stub mktemp \
   " : echo '/tmp/tempfile'"

  stub mv \
    "-f /tmp/tempfile v1-cache-key.tar : true"

  stub aws \
   "s3api head-object --bucket my-bucket --key 'my-org/my-pipeline/v1-cache-key.tar' --profile my-profile : true" \
   "s3 cp --profile my-profile --acl bucket-owner-full-control s3://my-bucket/my-org/my-pipeline/v1-cache-key.tar /tmp/tempfile : echo Copied from S3"

  stub tar \
   "-xf v1-cache-key.tar -C . : echo Extracted tar archive"

  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_S3_ARGS="--acl bucket-owner-full-control"
  export BUILDKITE_PLUGIN_CACHE_BACKEND="s3"
  export BUILDKITE_PLUGIN_CACHE_KEY="v1-cache-key"

  run "$PWD/hooks/pre-command"
  assert_success
  assert_output --partial "Copied from S3"
  assert_output --partial "Extracted tar archive"

  unset BUILDKITE_PLUGIN_CACHE_KEY
  unset BUILDKITE_PLUGIN_CACHE_BACKEND
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_ARGS
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG

  unstub mktemp
  unstub mv
  unstub aws
  unstub tar
}

@test "S3 download errors cause soft failure" {

  stub mktemp \
   " : echo '/tmp/tempfile'"

  stub aws \
   "s3api head-object --bucket my-bucket --key 'my-org/my-pipeline/v1-cache-key.tar' --profile my-profile : true" \
   "s3 cp --profile my-profile --acl bucket-owner-full-control s3://my-bucket/my-org/my-pipeline/v1-cache-key.tar /tmp/tempfile : false"

  export BUILDKITE_ORGANIZATION_SLUG="my-org"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_PLUGIN_CACHE_S3_BUCKET="my-bucket"
  export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-profile"
  export BUILDKITE_PLUGIN_CACHE_S3_ARGS="--acl bucket-owner-full-control"
  export BUILDKITE_PLUGIN_CACHE_BACKEND="s3"
  export BUILDKITE_PLUGIN_CACHE_KEY="v1-cache-key"

  run "$PWD/hooks/pre-command"
  assert_success
  assert_output --partial "S3 download failed"

  unset BUILDKITE_PLUGIN_CACHE_KEY
  unset BUILDKITE_PLUGIN_CACHE_BACKEND
  unset BUILDKITE_PLUGIN_CACHE_S3_PROFILE
  unset BUILDKITE_PLUGIN_CACHE_S3_ARGS
  unset BUILDKITE_PLUGIN_CACHE_S3_BUCKET
  unset BUILDKITE_PIPELINE_SLUG
  unset BUILDKITE_ORGANIZATION_SLUG

  unstub mktemp
  unstub aws
}