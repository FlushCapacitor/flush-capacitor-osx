#!/bin/sh

DIST_LIST_NAME=$1

CURL=curl
API_ENDPOINT=https://rink.hockeyapp.net/api/2/apps/upload

pwd
BUILD_SUBFOLDER=${TRAVIS_BUILD_DIR}/Build
echo $BUILD_SUBFOLDER
APP_PATH=${BUILD_SUBFOLDER}/FlushCapacitor.app
ZIP=${BUILD_SUBFOLDER}/FlushCapacitor.zip

zip -r9 $ZIP $APP_PATH

# HA_APP_TOKEN was secured by `travis encrypt` stored in .travis.yml

$CURL $API_ENDPOINT \
-H "X-HockeyAppToken: ${HA_APP_TOKEN}" \
-F ipa="@${IPA}" \
-F dsym="@${DSYM}" \
-F notify=0 \
-F status=2 \
-F tags="${DIST_LIST_NAME}"
