# Cache Buildkite Plugin [![Version badge](https://img.shields.io/badge/cache-v2.4.21-blue?style=flat-square)](https://buildkite.com/plugins) [![CI](https://github.com/nienbo/cache-buildkite-plugin/actions/workflows/ci.yml/badge.svg)](https://github.com/nienbo/cache-buildkite-plugin/actions/workflows/ci.yml) <!-- omit in toc -->

### Tarball, Rsync & S3 Cache Kit for Buildkite. Supports Linux, macOS and Windows* <!-- omit in toc -->

&ast; Windows requires **Git for Windows 2.25 or later**.

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) to restore and save
directories by cache keys. For example, use the checksum of a `.resolved` or `.lock` file
to restore/save built dependencies between independent builds, not just jobs.

With tarball or rsync, if source folder has changes, this will not fail your build, instead will surpress, notify and continue.

For S3, Instead of sync thousands of files, It just creates a tarball before S3 operation then copy this tarball to s3 at one time. This will reduce both time and cost on AWS billing.

Plus, In addition to tarball & rsync, we also do not re-create another tarball for same cache key if it's already exists.
<br /><br />


- [Backends](#backends)
  - [S3](#s3)
    - [S3-compatible Providers](#s3-compatible-providers)
    - [Google Cloud Storage Interoperability](#google-cloud-storage-interoperability)
    - [Storage Class](#storage-class)
    - [Additional Arguments](#additional-arguments)
  - [rsync](#rsync)
  - [tarball](#tarball)
- [Configurations](#configurations)
  - [Cache Key Templates](#cache-key-templates)
    - [Supported templates](#supported-templates)
  - [Hashing (checksum) against directory](#hashing-checksum-against-directory)
  - [Skip Cache on PRs](#skip-cache-on-prs)
  - [Skip cache upload](#skip-cache-upload)
  - [Advanced and Multiple usages in same pipeline](#advanced-and-multiple-usages-in-same-pipeline)
  - [Usage with docker](#usage-with-docker)
  - [Adjust compression level](#adjust-compression-level)
  - [Continue to cache on failed builds](#continue-to-cache-on-failed-builds)
  - [Multi-threaded compression](#multi-threaded-compression)
  - [Sharing caches between pipelines](#sharing-caches-between-pipelines)
  - [Keep the cache file between jobs/builds](#keep-the-cache-file-between-jobsbuilds)
  - [Auto deletion old caches](#auto-deletion-old-caches)
  - [Always upload Cache](#always-upload-cache)
  - [Globs on paths](#globs-on-paths)
- [Roadmap](#roadmap)

# Backends

Please see `lib/backends/*.sh` for available backends. You can fork, add your backend then send a PR here.

Available backends and their requirements:

| **Backend** | **Linux (GNU)**                                     | **macOS (BSD)**                                     | **Windows**    |
| ----------- | --------------------------------------------------- | --------------------------------------------------- | -------------- |
| `tarball`   | tar<br />sha1sum<br />jq                            | tar<br />shasum<br />jq                             | Same as Linux  |
| `rsync`     | rsync<br />sha1sum                                  | rsync <br />shasum                                  | Same as Linux* |
| `s3`        | aws-cli (`>= 1, ~> 2`)<br />tar<br/>sha1sum<br />jq | aws-cli (`>= 1, ~> 2`)<br />tar<br />shasum<br />jq | Same as Linux  |

### Windows Support  <!-- omit in toc -->

If you install **Git for Windows 2.25 or later**, you will benefit all features of Cache on Windows. Make sure you've added `bash.exe` into your `PATH`.

&ast; Rsync on Windows requires https://itefix.net/cwrsync. To be clear, except `rsync`, you can use `s3` and `tarball` on Windows without an additional app.

For `restore-keys` support, please download `jq` and add it to the `PATH`: https://stedolan.github.io/jq/download/

### jq <!-- omit in toc -->

To `restore-keys` support works, you need `jq` command available in your `PATH`. Buildkite **AWS EC2 Elastic Stack** already has `jq` installed by default. But, If you use custom environment or on Windows, please install `jq` (or `jq.exe`) first or stick with `key` only. If no `jq` found on your system, even if you provide restore-keys, it will be silently discarded. **You do not need `jq` if you are not using `s3` backend.**

## S3

S3 backend uses **AWS CLI** v**1** or v**2** to copy and download from/to S3 bucket or s3-compatible bucket. To be precisely, backend simply uses `aws s3 cp` command for all operations. Before that, we do `head-object` to check existence of the cache key on target bucket. While tarball is the default backend, S3 backend is heavily tested and ready for use in production. See some examples below for S3 backend.

**As of v2.4.2, this is the Recommended backend for cache**

```yml
steps:
  - plugins:
    - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        compress: true # Create tar.gz instead of .tar (Compressed) Defaults to `false`.
        compress-program: gzip # Allows for custom compression backends - i.e. pigz. Defaults to `gzip`.
        s3:
          profile: "other-profile" # Optional. Defaults to `default`.
          bucket: "s3-bucket"
          class: STANDARD # Optional. Defaults to empty which is usually STANDARD or based on policy.
          args: '--option 1' # Optional. Defaults to empty. Any optional argument that can be passed to aws s3 cp command.
          save-cache: true # Optional. Saves the cache on temp folder and keep between builds/jobs on the same machine.
          save-cache-dir: /mnt/cache # Optional. Where to save the cache if `save-cache` is enabled.
        paths:
          - 'bundle/vendor'
```

The paths are synced using Amazon S3 into your bucket using a structure of
`organization-slug/pipeline-slug/cache_key.tar`, as determined by the Buildkite environment
variables.

### S3-compatible Providers

Use `endpoint` and `region` fields to pass host and region parameters to be able to use S3-compatible providers. For example:

```yml
steps:
  - plugins:
    - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        s3:
          bucket: "s3-bucket"
          endpoint: "https://s3.nl-ams.scw.cloud"
          region: "nl-ams" # Optional. Defaults to `host` one.
          # Alternative: If you strictly need to specify host and region manually, then use like this:
          # args: "--endpoint-url=https://s3.nl-ams.scw.cloud --region=nl-ams"
        paths:
          - 'bundle/vendor'
```

Or, alternatively you can define them in your `environment` file like this:

```bash
export BUILDKITE_PLUGIN_CACHE_S3_ENDPOINT="https://s3.nl-ams.scw.cloud"
# Optionally specify region:
export BUILDKITE_PLUGIN_CACHE_S3_REGION="nl-ams"
```

### Google Cloud Storage Interoperability

Though native Google Cloud Storage is on the roadmap, it is possible to use
this plugin via [Google Cloud Storage interoperability](https://cloud.google.com/storage/docs/interoperability).

Enabling this interoperability in Google Cloud Storage will generate the respective HMAC keys that are equivalent to the
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. An example configuration is:

```yml
steps:
  - plugins:
    - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
        compress: true # Create tar.gz instead of .tar (Compressed) Defaults to `false`.
        s3:
          bucket: 'gcs-bucket'
          args: '--endpoint-url=https://storage.googleapis.com --region=us-east1'
          # Alternatively, you can use these 2 inputs instead of `args`:
          # endpoint: "https://storage.googleapis.com"
          # region: "us-east1"
```

However, as GCS does not support multipart uploads, it is required to disable this in the AWS CLI. This
can be done in a variety of ways, but a simple approach is using a `pre-command` hook:

```bash
# The AWS CLI is used for uploading cached deps to GCS. Multipart uploads need
# to be disabled as they don't work in GCS but the only way to disable them is
# to just set a very high threshold
echo '--- :aws: Disable multipart uploads in AWS CLI'
aws configure set default.s3.multipart_threshold 5GB
```

### Storage Class

You can pass `class` option for the following classes:

- `STANDARD`
- `STANDARD_IA`
- `ONEZONE_IA`
- `INTELLIGENT_TIERING`

Default value will always be empty. This means, AWS or Compatible provider will use its default value for stored object or a value that given by Lifecycle policy.

### Additional Arguments

You can pass `args` argument with required options. This arguments will be added to the end of `s3 cp` command. Therefore please do not add following options:

- `--storage-class`
- `--profile`
- `--endpoint-url`
- `--region`

However, If you do not specify `profile`, `endpoint`, `region` and `class` via YAML configuration, then you can pass those arguments to the `args`.

## rsync

You can also use rsync to store your files using the `rsync` backend. Files will neither compressed nor packed.

```yml
steps:
  - plugins:
    - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: rsync
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        rsync:
          path: '/tmp/buildkite-cache' # Defaults to /tmp with v2.4.10+
        paths:
          - 'bundle/vendor'
```

The paths are synced using `rsync_path/cache_key/path`. This is useful for maintaining a local
cache directory, even though this cache is not shared between servers, it can be reused by different
agents/builds.

## tarball

You can also use tarballs to store your files using the `tarball` backend. Files will not be compressed but surely packed into single archive.

*As of v2.4.2, tarball is no longer recommended backend. Especially but not limited to If you are on AWS Elastic Stack, please use S3 backend.*

**tarball is still the default backend.**

```yml
steps:
  - plugins:
    - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: tarball
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        compress: true # Create tar.gz instead of .tar (Compressed) Defaults to `false`.
        tarball:
          path: '/tmp/buildkite-cache' # Defaults to /tmp with v2.4.10+
          max: 7 # Optional. Removes tarballs older than 7 days.
        paths:
          - 'bundle/vendor'
```

The paths are synced using `tarball_path/cache_key.tar`. This is useful for maintaining a local
cache directory, even though this cache is not shared between servers, it can be reused by different
agents/builds.

# Configurations
## Cache Key Templates

The cache key is a string, which support a crude template system. Currently `checksum` is
the only command supported for now. It can be used as in the example above. In this case
the cache key will be determined by executing a _checksum_ (actually `sha1sum`) on the
`Gemfile.lock` file, prepended with `v1-cache-{{ runner.os }}-`.

### Supported templates

| **Template**                                                | **Translated**                                                                                                                                                          |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`                                                        | `id` of your cache. Defaults to **empty**.                                                                                                                              |
| `runner.os`                                                 | **One of**:<br />Windows<br />Linux<br />macOS<br />Generic                                                                                                             |
| `checksum 'file_name'` - or -<br />`checksum './directory'` | File: sha1 of that file<br />Directory: **sorted** hashing of the whole directory.                                                                                      |
| `date 'format'`                                             | Prints the current timestamp with given format. Useful when you want to catalog your caches or expire them on date (daily, weekly or monthly...). E.g.: `date '+%Y-%m'` |
| `git.branch`                                                | For example: `master`.<br />Derived from `${BUILDKITE_BRANCH}`                                                                                                          |
| `git.commit`                                                | For example: `9576a34...`. (Full SHA).<br />Derived from `${BUILDKITE_COMMIT}`                                                                                          |
| `env.FOO`                                                   | Value in environment variable `FOO`                                                                                                                                     |

## Hashing (checksum) against directory

Along with lock files, you can calculate directory that contains multiple files or recursive directories and files.

```yml
steps:
  - plugins:
    - nienbo/cache#v2.4.21:
        id: node # or node-16
        backend: tarball # Optional. Default `backend` is already set to `tarball`
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum './app/javascript' }}" # Calculate whole 'app/javascript' recursively
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        compress: true # Create tar.gz instead of .tar (Compressed) Defaults to `false`.
        tarball:
          path: '/tmp/buildkite-cache' # Defaults to /tmp with v2.4.10+
          max: 7 # Optional. Removes tarballs older than 7 days.
        paths:
          - node_modules
```

For example, you can calculate total checksum of your javascript folder to skip build, If the source didn't changed.

Note: Before hashing files, we do sorting via `sort`. This makes exact same sorted and hashed content against very same directory between different builds.

## Skip Cache on PRs

You can skip caching on Pull Requests (Merge Requests) by simply adding `pr: false` to the cache plugin. For example;

```yml
steps:
  - plugins:
    - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        pr: false # Default to `true` which is do cache on PRs.
        compress: true # Create tar.gz instead of .tar (Compressed) Defaults to `false`.
        s3:
          profile: "other-profile" # Optional. Defaults to `default`.
          bucket: "s3-bucket"
          class: STANDARD # Optional. Defaults to empty which is usually STANDARD or based on policy.
          args: '--option 1' # Optional. Defaults to empty. Any optional argument that can be passed to aws s3 cp command.
        paths:
          - 'bundle/vendor'
```

Or you can set this by Environment:

```bash
#!/bin/bash

export BUILDKITE_PLUGIN_CACHE_PR=false
```

## Skip cache upload

You can skip the cache upload at the end of a build step by using `upload-cache`. The possible values are:

| **Value**             | **Behavior**                                                                                  |
| --------------------- | --------------------------------------------------------------------------------------------- |
| `true` (default)      | Cache will be uploaded at the end of the build step                                           |
| `false`               | Cache upload will be skipped.                                                                 |
| `default-branch-only` | Cache will only upload on the default branch (defined by `BUILDKITE_PIPELINE_DEFAULT_BRANCH`) |

```yml
steps:
  - plugins:
    - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
        s3:
          bucket: "s3-bucket"
        paths:
          - 'bundle/vendor'
        upload-cache: false # Defaults to `true`

```

## Advanced and Multiple usages in same pipeline

```yaml
node-cache: &node-cache
  id: node # or node-16
  key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'yarn.lock' }}"
  restore-keys:
    - 'v1-cache-{{ id }}-{{ runner.os }}-'
    - 'v1-cache-{{ id }}-'
  backend: s3
  s3:
    bucket: cache-bucket
  paths:
    - node_modules
    # If you have sub-dir then use:
    # - **/node_modules

ruby-cache: &ruby-cache
  id: ruby # or ruby-3.0
  key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
  restore-keys:
    - 'v1-cache-{{ id }}-{{ runner.os }}-'
    - 'v1-cache-{{ id }}-'
  backend: s3
  s3:
    bucket: cache-bucket
  paths:
    - 'bundler/vendor'

all-plugins: &all-plugins
  - nienbo/cache#v2.4.21: *node-cache
  - nienbo/cache#v2.4.21: *ruby-cache
  - docker#v3.7.0: ~ # Use your config here

steps:
  - name: ':jest: Run tests'
    key: test
    command: yarn test --runInBand && bundle exec rspec --color
    plugins: *all-plugins
  - name: ':istanbul: Run Istanbul'
    key: istanbul
    depends_on: test
    command: .buildkite/steps/istanbul.sh
    plugins: *all-plugins
```

## Usage with docker

Put cache plugin **before** `docker` or `docker-compose` plugins. Let's cache do the rest restoring and caching afterwards.

```yaml
steps:
  - name: ':jest: Run tests'
    key: jest
    command: yarn test --runInBand
    plugins:
      - nienbo/cache#v2.4.21: # Define cache *before* docker plugins.
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        pr: false
        s3:
          bucket: s3-bucket
        paths:
          - bundle/vendor
      - docker#v3.7.0: ~ # Use your config here
      - docker-compose#3.7.0: ~ # Or compose. Use your config here
```
## Adjust compression level

You can pass numbers to `compress` argument. Default is `false` means no compression. If you pass `true` then default compression (`6`) will be used. You can provide compression level from 0 to 9. 0 means least, 9 means best compression (Causes intensive CPU usage).

```yaml
steps:
  - name: ':jest: Run tests'
    key: jest
    command: yarn test --runInBand
    plugins:
      - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        pr: false
        compress: 2 # fast compression.
        s3:
          bucket: s3-bucket
        paths:
          - bundle/vendor
```

Or, alternatively you can use environments globally:

```bash
export BUILDKITE_PLUGIN_CACHE_COMPRESS=2
```

## Continue to cache on failed builds

There is a possibility to do cache and send to S3 or Tarball storage when a build failed (aka. `non-zero exit code`). This is possible via `continue_on_error` option key as follow:

```yaml
steps:
  - name: ':jest: Run tests'
    key: jest
    command: yarn test --runInBand
    plugins:
      - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        pr: false
        compress: 2 # fast compression.
        s3:
          bucket: s3-bucket
        paths:
          - bundle/vendor
        continue_on_error: true # Cache will be made even build fails.
```

## Multi-threaded compression

You can benefit tar's `compress-program` option to allow multi-threaded compression. Thus, all you need to pass this option to the plugin as below:

```yaml
steps:
  - name: ':jest: Run tests'
    key: jest
    command: yarn test --runInBand
    plugins:
      - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        compress: 2 # fast compression.
        s3:
          bucket: s3-bucket
        paths:
          - bundle/vendor
        compress-program: pigz # tar will use `pigz` to compress and benefit multithreading...
```

## Sharing caches between pipelines

If you have multiple pipelines that can benefit from referencing the same cache, you can use the `pipeline-slug-override` option:

```yaml
steps:
  - name: ':jest: Run tests'
    key: jest
    command: yarn test --runInBand
    plugins:
      - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        compress: 2 # fast compression.
        s3:
          bucket: s3-bucket
        paths:
          - bundle/vendor
        pipeline-slug-override: "other-pipeline" # other-pipeline references the same Gemfile.lock
```

## Keep the cache file between jobs/builds

To prevent re-downloading the same cache again and place it to a temporary directory then copy when necessary use the `save-cache` option as follows:

```yaml
steps:
  - name: ':jest: Run tests'
    key: jest
    command: yarn test --runInBand
    plugins:
      - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        compress: 2 # fast compression.
        s3:
          bucket: s3-bucket
          save-cache: true # Optional. Saves the cache on temp folder and keep between builds/jobs on the same machine. Defaults to `false`
          save-cache-dir: /mnt/cache # Optional. Where to save the cache if `save-cache` is enabled.
        paths:
          - bundle/vendor
```

## Auto deletion old caches

For tarballs, To keep caches and delete them in _for example_ 7 days, use `max: 7`.

For S3, As long as you use Lifcecycle policy (AWS and Scaleway supports this feature) you will only have caches for number of days you specify in your Lifecycle policy terms. This will allows you to invalidate old caches and save some storage costs.

## Always upload Cache

There are some cases where you want to process the cache no matter of what. In this scenario, use `always` option and set it to `true` (Defaults to `false`):

See #46 and #59 for details.

```yaml
steps:
  - name: ':jest: Run tests'
    key: jest
    command: yarn test --runInBand
    plugins:
      - nienbo/cache#v2.4.21:
        id: ruby # or ruby-3.0
        backend: s3
        key: "v1-cache-{{ id }}-{{ runner.os }}-{{ checksum 'Gemfile.lock' }}"
        restore-keys:
          - 'v1-cache-{{ id }}-{{ runner.os }}-'
          - 'v1-cache-{{ id }}-'
        compress: 2 # fast compression.
        always: true # Optional. Always process the cache and upload. Defaults to `false`
        s3:
          bucket: s3-bucket
        paths:
          - bundle/vendor
```

## Globs on paths

You can use glob pattern in paths (to be cached) after `v2.1.x`

# Roadmap

+ Google Cloud Storage support.
+ BitPaket Easy Storage support.
+ Azure Blob Storage support.

Copyright © 2025 Nienbo Corporation. All rights reserved.
