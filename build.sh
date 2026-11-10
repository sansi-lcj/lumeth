#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/Lumeth.app"
ASSETS="$ROOT/build/asset-out"

cd "$ROOT"
if [[ ! -f Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png ]]; then
    /usr/bin/swift scripts/make_icon.swift "$ROOT/Resources"
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Lumeth"

mkdir -p "$ASSETS"
xcrun actool Resources/Assets.xcassets \
    --compile "$ASSETS" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$ASSETS/partial.plist" >/dev/null

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Lumeth"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$ASSETS/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ASSETS/Assets.car" "$APP/Contents/Resources/Assets.car"

if [[ -d Resources/en.lproj ]]; then
    for lproj in Resources/*.lproj; do
        [[ -d "$lproj" ]] && cp -R "$lproj" "$APP/Contents/Resources/"
    done
fi

/usr/bin/codesign --force --deep --sign - "$APP" >/dev/null
echo "$APP"
