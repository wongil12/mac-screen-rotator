#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
configuration=${1:-release}
app_dir="$project_root/dist/Mac Screen Rotator.app"
contents_dir="$app_dir/Contents"
displayplacer_path=${DISPLAYPLACER_PATH:-$(command -v displayplacer || true)}

if [[ -z "$displayplacer_path" || ! -x "$displayplacer_path" ]]; then
    print -u2 "displayplacer가 필요합니다: brew install displayplacer"
    exit 1
fi

cd "$project_root"
env CLANG_MODULE_CACHE_PATH=.build/clang-module-cache \
    swift build -c "$configuration" \
    --cache-path .build/cache \
    --config-path .build/config \
    --security-path .build/security

mkdir -p "$contents_dir/MacOS" "$contents_dir/Helpers" "$contents_dir/Resources"
cp ".build/$configuration/MacScreenRotator" "$contents_dir/MacOS/MacScreenRotator"
cp ".build/$configuration/screen-rotator-failsafe" "$contents_dir/Helpers/screen-rotator-failsafe"
cp "$displayplacer_path" "$contents_dir/Helpers/displayplacer"
cp Resources/Info.plist "$contents_dir/Info.plist"
cp Resources/displayplacer-LICENSE.txt "$contents_dir/Resources/displayplacer-LICENSE.txt"
xcrun actool Resources/Assets.xcassets \
    --compile "$contents_dir/Resources" \
    --platform macosx \
    --minimum-deployment-target 15.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$project_root/.build/AppIcon-Info.plist"

chmod 755 "$contents_dir/MacOS/MacScreenRotator" \
    "$contents_dir/Helpers/displayplacer" \
    "$contents_dir/Helpers/screen-rotator-failsafe"

if [[ -n "${MAC_ROTATOR_SIGNING_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp \
        --sign "$MAC_ROTATOR_SIGNING_IDENTITY" \
        "$contents_dir/Helpers/displayplacer"
    codesign --force --options runtime --timestamp \
        --sign "$MAC_ROTATOR_SIGNING_IDENTITY" \
        "$contents_dir/Helpers/screen-rotator-failsafe"
    codesign --force --deep --options runtime --timestamp \
        --sign "$MAC_ROTATOR_SIGNING_IDENTITY" \
        "$app_dir"
else
    codesign --force --deep --sign - "$app_dir"
fi

codesign --verify --deep --strict --verbose=2 "$app_dir"
print "$app_dir"
