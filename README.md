# Cache Buildkite Plugin

### Tarball, Rsync & S3 Cache Kit for Buildkite. Supports Linux and macOS.

_(Windows is on the way)_



A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) to restore and save
directories by cache keys. For example, use the checksum of a `.resolved` or `.lock` file
to restore/save built dependencies between independent builds, not just jobs.

With tarball or rsync, if source folder has changes, this will not fail your build, instead will surpress, notify and continue.

For S3, Instead of sync thousands of files, It just creates a tarball before S3 operation then copy this tarball to s3 at one time. This will reduce both time and cost on AWS billing.

Plus, In addition to tarball & rsync, we also do not re-create another tarball for same cache key if it's already exists.

## Restore & Save Caches

```yml
steps:
  - plugins:
    - gencer/cache#v2.0.9:
        cache_key: "v1-cache-{{ checksum 'Podfile.lock' }}"
        paths: [ "Pods/", "Rome/" ]
```

## Cache Key Templates

The cache key is a string, which support a crude template system. Currently `checksum` is
the only command supported for now. It can be used as in the example above. In this case
the cache key will be determined by executing a _checksum_ (actually `sha1sum`) on the
`Podfile.lock` file, prepended with `v1-cache-`.

## S3 Storage (Using tarball)

This plugin uses AWS S3 cp to cache the paths into a bucket as defined by environment
variables defined in your agent.

```yml
steps:
  - plugins:
    - gencer/cache#v2.0.9:
        s3_storage: true
        s3_profile: "my-s3-profile"
        s3_bucket_name: "my-unique-s3-bucket-name"
        cache_key: "v1-cache-{{ checksum 'Podfile.lock' }}"
        paths: [ "Pods/", "Rome/" ]
```

The paths are synced using Amazon S3 into your bucket using a structure of
`organization-slug/pipeline-slug/cache_key.tar`, as determined by the Buildkite environment
variables.

## Rsync Storage

You can also use rsync to store your files using the ``rsync_storage`` config parameter.
If this is set it will be used as the destination parameter of a ``rsync -az`` command.

```yml
steps:
  - plugins:
    - gencer/cache#v2.0.9:
        rsync_storage: '/tmp/buildkite-cache'
        cache_key: "v1-cache-{{ checksum 'Podfile.lock' }}"
        paths: [ "Pods/", "Rome/" ]
```

The paths are synced using `rsync_storage/cache_key/path`. This is useful for maintaining a local
cache directory, even though this cache is not shared between servers, it can be reused by different
agents/builds.

## Tarball Storage

You can also use tarballs to store your files using the ``tarball_storage`` config parameter.
If this is set it will be used as the destination parameter of a ``tar -cf`` command.

```yml
steps:
  - plugins:
    - gencer/cache#v2.0.9:
        tarball_storage: '/tmp/buildkite-cache'
        tarball_keep_max_days: 7 # Optional. Removes tarballs older than 7 days.
        cache_key: "v1-cache-{{ checksum 'Podfile.lock' }}"
        paths: [ "Pods/", "Rome/" ]
```

The paths are synced using `tarball_storage/cache_key.tar`. This is useful for maintaining a local
cache directory, even though this cache is not shared between servers, it can be reused by different
agents/builds.

## Hashing (checksum) against directory

Along with lock files, you can calculate directory that contains multiple files.

```yml
steps:
  - plugins:
    - gencer/cache#v2.0.9:
        tarball_storage: '/tmp/buildkite-cache'
        tarball_keep_max_days: 7 # Optional. Removes tarballs older than 7 days.
        cache_key: "v1-cache-{{ checksum './app/javascript' }}" # Calculate whole 'app/javascript' directory
        paths: [ "Pods/", "Rome/" ]
```

For example, you can calculate total checksum of your javascript folder to skip build, if source didn't changed.

## Keeping caches for `X` days

To keep caches and delete them in -for example- 7 days, use tarball storage and use `tarball_keep_max_days`. On S3 side, please use S3 Policy for this routine. Each uploaded file to S3 will be deleted according to your file deletion policy.

There is one catch here, in tarball storage we do not re-create another tarball if its already exists on the disk. This is not the case for S3 tarball upload. Due to expiration policy, we just re-upload the same tarball to refresh expiration date. So as long as you use the same cache, S3 will not delete it. Otherwise, It will be deleted from S3-side if not used in a manner time.

## Roadmap

+ Adding support for Windows.
+ Move functions to `shared.bash`.
+ Google Cloud Cache Support.

Original work by [@danthorpe]( https://github.com/danthorpe/cache-buildkite-plugin)

Copyright (C) 2020 Gencer W. Genç.

Licensed as **MIT**.
