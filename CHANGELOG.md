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
