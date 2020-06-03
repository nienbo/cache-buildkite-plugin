# v2.1.0 **Not yet released! !WIP!**

+ Added `os` props to S3 Uploads. This will make S3 uploads OS-aware. So caching on linux will not be restored on Windows or Mac... To enable this set `os` to `true` on S3 setting.
+ Added `shared` prop. This will make sure cached data available across all pipelines. Default to `false`.
  Use cases:
    In some cases, you may have multiple pipelines for the same project. For example one pipeline for tests and other for deploy. In this case, codebase also is the same and you can safely cache and share data across those pipelines.
+ S3 uploads are now defiend in pipeline instead of ENV variables.

# v2.0.6

+ macOS compatibility

# v2.0.5

+ Fix checksum for files with dashes in them
* Fix incorrect `tr` usage by @xthexder
* Use `shasum` on macOS.

# v2.0.3

+ Skip cache at top level if `key` not provided
+ Check if tar file exists on `s3` before `cp`.
* + Make AWS Profile optional
* `sync -> cp` command changed

# v2.0.2

+ Skip cache if exit status iz not zero

# v2.0.1

+ Fix unbound variable

# v2.0.0

+ `sha1sum` instead of shasum due to Linux AMI on AWS doesn't have `shasum`.
+ Added Tarball storage
+ S3 Tarball `cp` feature
+ Skip create on tarball if cache key already exists
+ Soft-fail on missing or vanished files on rsync (Won't fail your build)
+ Soft-fail on missing folders on tarball (Won't fail your build)
+ Keep **X days** of backups on tarball and remove olders if given by cache setting.

# v1.0.0
See original repository.
