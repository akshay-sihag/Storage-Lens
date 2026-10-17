#!/bin/bash
# Storage Lens — By Eridyn
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
APP="build/Storage Lens.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
xcrun swiftc -swift-version 5 -target arm64-apple-macos14.0 -O Sources/StorageCore.swift Sources/StorageModel.swift Sources/StorageLensApp.swift -o "$APP/Contents/MacOS/StorageLens" -framework Cocoa -framework SwiftUI -framework Charts
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built Storage Lens 1.1.3 — By Eridyn\n'
