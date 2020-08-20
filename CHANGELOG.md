# v2.0.9

+ Fix `--ignore-failed-read` which is not supported on macOS. See #5.

# v2.0.8

+ Fix `"` and `'` (single/double quotes) issues on docker image that used in EC2 instances.

# v2.0.7

+ S3 uploads are now defiend in pipeline instead of ENV variables.
+ Ability to hash directory.
+ Improved terminal output with emojis (_and printing current cache version_)

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
