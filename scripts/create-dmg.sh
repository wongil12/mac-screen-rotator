#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
app_dir="$project_root/dist/Mac Screen Rotator.app"
output_path=${1:-"$project_root/dist/Mac-Screen-Rotator.dmg"}
staging_dir=$(mktemp -d)

cleanup() {
    /bin/rm -rf "$staging_dir"
}
trap cleanup EXIT

if [[ ! -d "$app_dir" ]]; then
    print -u2 "앱 번들이 없습니다. 먼저 scripts/build-app.sh를 실행하세요."
    exit 1
fi

cp -R "$app_dir" "$staging_dir/Mac Screen Rotator.app"
ln -s /Applications "$staging_dir/Applications"

mkdir -p "${output_path:h}"
/bin/rm -f "$output_path"
hdiutil create \
    -volname "Mac Screen Rotator" \
    -srcfolder "$staging_dir" \
    -ov \
    -format UDZO \
    "$output_path"

print "$output_path"
