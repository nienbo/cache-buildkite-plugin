[![Build Status](https://badge.buildkite.com/de63a1199fbe2ee8a8d7521bfc35f515934d638fa06b6aa9b1.svg?branch=master)](https://buildkite.com/blindingskies/cache-buildkite-plugin)

# Cache Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) to restore and save 
directories by cache keys. For example, use the checksum of a `.resolved` or `.lock` file 
to restore/save built dependencies between independent builds, not just jobs. 

## Restore & Save Caches

```yml
steps:
  - plugins:
    - danthorpe/cache#v1.0.0:
        cache_key: "v1-cache-{{ checksum 'Podfile.lock' }}"
        paths: [ "Pods/", "Rome/" ]
```

## Cache Key Templates

The cache key is a string, which support a crude template system. Currently `checksum` is 
the only command supported for now. It can be used as in the example above. In this case
the cache key will be determined by executing a _checksum_ (actually `shasum`) on the 
`Podfile.lock` file, prepended with `v1-cache-`.

## S3 Storage

This plugin uses AWS S3 sync to cache the paths into a bucket as defined by environment 
variables defined in your agent. 

```bash
export BUILDKITE_PLUGIN_CACHE_S3_BUCKET_NAME="my-unique-s3-bucket-name"
export BUILDKITE_PLUGIN_CACHE_S3_PROFILE="my-s3-profile"
```

The paths are synced using Amazon S3 into your bucket using a structure of 
`organization-slug/pipeline-slug/cache_key`, as determined by the Buildkite environment 
variables.