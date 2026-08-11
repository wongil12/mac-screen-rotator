#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
profile=${1:?"사용법: scripts/notarize-app.sh <notarytool-keychain-profile>"}
app_dir="$project_root/dist/Mac Screen Rotator.app"
archive="$project_root/dist/MacScreenRotator.zip"

if [[ ! -d "$app_dir" ]]; then
    print -u2 "먼저 scripts/build-app.sh를 실행하세요."
    exit 1
fi

ditto -c -k --keepParent "$app_dir" "$archive"
xcrun notarytool submit "$archive" --keychain-profile "$profile" --wait
xcrun stapler staple "$app_dir"
xcrun stapler validate "$app_dir"
spctl --assess --type execute --verbose=2 "$app_dir"
