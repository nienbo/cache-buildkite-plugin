# main

+ Fix restore on tarball backend. See #43.

# v2.4.10

+ Allow multithreaded compression using additional compressing tools like `pigz` via `compress-program` option. See #38.

# v2.4.9

+ Add an option to allow caching on non-zero exit codes via `continue_on_error` option key. See #33.
+ Fix: S3 args are passed to head-object call which is incompatible with `cp`. See #35.

# v2.4.8

+ Using `{{ git.branch }}` cache-key with a `/` in the branch name. See #26.

# v2.4.7

+ Use Array to prevent escaping arguments with quote on tar commands
+ Final release for `compress` option key

# v2.4.6

+ Tidied tarball calls
+ Adjustable compression option. Now you can decide ratio from `0` to `9` on compressed tarballs (Applies to tarball and s3 backends)

# v2.4.5

+ Allow globs in tarballs when used with s3 **with multiple paths**. v2.4.4 only enabled for single path only.

# v2.4.4

+ Allow globs in tarballs when used with s3

# v2.4.3

+ Fixed unnecessary quotes on endpoint and region. This causes aws operation fail when `endpoint` and `region` used instead of `args`.
  
# v2.4.2

+ Added `id` key to supported cache key templates. You can use in your keys as `{{ id }}`

# v2.4.1

+ Added `id` support to identify cache's by ID.

# v2.4.0

+ `restore-keys` support for incremental cache and key lookup. **Requires** `jq`. See #20.
+ `git.commit` and `git.branch` support in cache key templates. See README.

# v2.3.10

+ Don't upload anything unconditionally to S3. See #21.

# v2.3.9

+ Add `endpoint` and `region` support to S3 backend. See README for this change.
+ Default path for `tarball` and `rsync` is now set to `/tmp`.

# v2.3.8

+ Add $BK_AWS_ARGS to head-object call See #19.
+ Fix README docker example

# v2.3.7

+ Do not check for `busybox` on macOS. See #17.

# v2.3.6

+ Added checking for `busybox` and fallback to lesser options of `tar`.
+ Use `-exec` with `rm -f` using `find` instead of native `-delete` option.

# v2.3.5

+ Added `args` and `class` options to `s3` backend. See README for details.
+ Small changes

# v2.3.4

+ Many variables perepended with `BK_CACHE_` to avoid conflict with local variables. More will come.

# v2.3.3

+ Added `{{ runner.os }}` helper to separate caches between runner operating systems.

# v2.3.2

+ Added `compress` option to `s3` and `tarball` which creates tar.gz instead of tar.

# v2.3.1

+ Add Glob Support on `paths`. See #13.

# v2.3.0

+ Ability to skip cache on PR-triggered builds. See README.
  
# v2.2.1

+ Fix possible failure at tarball cleanup. See #12. ([@djmarcin]( https://github.com/djmarcin))

# v2.2.0

+ Modular system. Backends and shared functions goes into their own files.

# v2.1.0

+ Improved templating support. Moving shared function to `shared.bash` See #8 and #9. ([@djmarcin]( https://github.com/djmarcin))
+ Added tests and rewarp the code. See #10. ([@djmarcin]( https://github.com/djmarcin))

# v2.0.10

+ Concurrent writers to tar files clobber each other. See #6. ([@djmarcin]( https://github.com/djmarcin))

# v2.0.9

+ Fix `--ignore-failed-read` which is not supported on macOS. See #5.

# v2.0.8

+ Fix `"` and `'` (single/double quotes) issues on docker image where used in EC2 instances.

# v2.0.7

+ S3 uploads are now defiend in pipeline instead of ENV variables.
+ Ability to hash directories.
+ Improved terminal output with emojis (_and printing current cache version_)

# v2.0.6

+ macOS compatibility

# v2.0.5

+ Fix checksum for files with dashes in them
+ Fix incorrect `tr` usage by @xthexder
+ Use `shasum` on macOS.

# v2.0.3

+ Skip cache at top level if `key` not provided
+ Check if tar file exists on `s3` before `cp`.
+ Make AWS Profile optional
+ `sync -> cp` command changed

# v2.0.2

+ Skip cache if exit status is not zero

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
