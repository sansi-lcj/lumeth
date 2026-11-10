#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! security find-identity -v -p codesigning | grep -q "Apple Distribution"; then
    echo "Missing a valid Apple Distribution signing identity." >&2
    echo "Renew it in Apple Developer Certificates for team SV2LZPC92A." >&2
    exit 1
fi

xcodegen generate
xcodebuild \
    -project Lumeth.xcodeproj \
    -scheme Lumeth \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath build/Lumeth.xcarchive \
    -allowProvisioningUpdates \
    archive

xcodebuild \
    -exportArchive \
    -archivePath build/Lumeth.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist scripts/ExportOptions.plist \
    -allowProvisioningUpdates

echo "Exported to build/export"
