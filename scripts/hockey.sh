#!/bin/sh

DIST_LIST_NAME=$1

CURL=curl
API_ENDPOINT=https://rink.hockeyapp.net/api/2/apps/upload

BUILD_SUBFOLDER=${TRAVIS_BUILD_DIR}/Build
ZIP=${BUILD_SUBFOLDER}/FlushCapacitor.app.zip

pushd $BUILD_SUBFOLDER
zip -r9 $ZIP FlushCapacitor.app
popd

# HA_APP_TOKEN was secured by `travis encrypt` stored in .travis.yml

$CURL $API_ENDPOINT \
-H "X-HockeyAppToken: $HA_APP_TOKEN" \
-F "ipa=@$ZIP" \
-F "notify=0" \
-F "status=2" \
-F "tags=${DIST_LIST_NAME}"
