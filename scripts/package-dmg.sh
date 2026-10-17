#!/bin/bash
# Storage Lens — By Eridyn. Two-icon drag-to-Applications installer.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
APP="build/Storage Lens.app"
test -x "$APP/Contents/MacOS/StorageLens" || ./scripts/build.sh
codesign --verify --deep --strict "$APP"
mkdir -p build dist
if [ ! -x build/dmg-tools/bin/dmgbuild ]; then
    python3 -m venv build/dmg-tools
    build/dmg-tools/bin/pip install 'dmgbuild==1.6.5'
fi
xcrun swift scripts/make-dmg-background.swift build/dmg-background.tiff
build/dmg-tools/bin/dmgbuild -s scripts/dmg-settings.py -D "project=$PROJECT_DIR" "Storage Lens - Eridyn" "dist/Storage-Lens-1.1.3-arm64.dmg"
hdiutil verify "dist/Storage-Lens-1.1.3-arm64.dmg"
shasum -a 256 "dist/Storage-Lens-1.1.3-arm64.dmg" > dist/SHA256SUMS.txt
