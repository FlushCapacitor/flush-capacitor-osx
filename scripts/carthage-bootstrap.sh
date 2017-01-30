#!/bin/sh

# CircleCI Carthage build caching, per idea at
# https://robots.thoughtbot.com/caching-carthage-con-circleci
#
# Cartfile.resolved is a checksum of successful "carthage checkout" or "carthage bootstrap"
# It is recommended to commit in repo. On the other hand, it is NOT recommended to commit
# the checkout folder Carthage/ much the same way as Pods/ or node_modules/. However, there is
# no problem with having the folder CACHED, which means that it persists on CCI side.
# So if it's desirable to update it only as needed:
# 0. cache Carthage/ subdir on CCI side
# 1. compare the commited latest Cartfile.resolved with a copy under Carthage/
# 2. if not equal, redo checkout and build (i.e. bootstrap)
# 3. replace Cartfile.resolved in Carthage/
#
if ! cmp -s Cartfile.resolved Carthage/Cartfile.resolved; then
  carthage bootstrap --platform Mac --toolchain com.apple.dt.toolchain.XcodeDefault
  cp Cartfile.resolved Carthage
else
  echo "Cartfile.resolved up to date, bootstrap not needed"
fi

