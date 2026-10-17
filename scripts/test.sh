#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
mkdir -p build/tests
xcrun swiftc -swift-version 5 Sources/StorageCore.swift Sources/StorageModel.swift Tests/main.swift -o build/tests/safety-tests -framework Cocoa -framework SwiftUI
build/tests/safety-tests
