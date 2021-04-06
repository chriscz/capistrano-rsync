## Unreleased
- Restructure to modern Capistrano SCM
## 1.4.0 (Jan 25, 2017)
- Adds option to bypass clone stage.

## 1.3.5 (Sep 7, 2015)
- Adds clean command to submodules to remove untracking files.
- Rectifies the tag deployment.

## 1.3.4 (Jul 17, 2015)
- Added ``:git_remote`` option. Gives the opportunity to define some other remote that ``origin``.

## 1.3.3 (Jul 15, 2015)
- Adds support for checking out revisions on top of tags and branches (rsync_checkout_tag is now deprecated)

## 1.3.0 (Jul 2, 2015)
- Refactored library to use run_locally and execute from Capistrano, so the output is uniformized & we exit on failed commands
- Added some options as well (see README.md for complete list)
- [BC BREAK] Execution context may have changed, if you've overridden some options taking into account execution path for instance.

## 1.1.0 (Jan 17, 2015)
- Added ``:rsync_sparse_checkout`` option

## 1.0.3 (Jul 10, 2014)
- Added ``set_current_revision`` task
- Added ``:rsync_target_dir`` variable to specify the target dir in the rsync operation

## 1.0.2 (Oct 13, 2013)
- Updates README and code comments.

## 1.0.1 (Sep 2, 2013)
- Updates README and adds implementation details to it.

## 1.0.0 (Sep 2, 2013)
- Makes the `rsync:stage` task public for extending and hooking.
- Renames `rsync:create_release` to `rsync:release`. Old name still works.
- Adds optional caching to `rsync_cache` directory on the server.

## 0.2.1 (Sep 1, 2013)
- Fixes starting with no previous local repository cache.
  Note to self: Avoid writing code without integration tests.

## 0.2.0 (Sep 1, 2013)
- Passes user given in `role :app, "user@host"` to `rsync` if set.

## 0.1.338 (Sep 1, 2013)
- Adds gem dependency on Capistrano v3.

## 0.1.337 (Sep 1, 2013)
- First release. Let's get syncing!
