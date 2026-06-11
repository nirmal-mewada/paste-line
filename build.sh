#!/bin/bash
set -e

echo "=== Building PasteLine ==="

# 1. Create directory structure
APP_DIR="PasteLine.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating App Bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 2. Compile Swift sources
echo "Compiling Swift source files..."
swiftc Sources/PasteLine/*.swift \
    -o "$MACOS_DIR/PasteLine" \
    -O \
    -framework AppKit \
    -framework SwiftUI \
    -framework Carbon \
    -framework Foundation

# 3. Copy Plist metadata
echo "Copying Info.plist..."
cp Sources/PasteLine/Info.plist "$CONTENTS_DIR/Info.plist"

echo "=== Build Completed Successfully! ==="
echo "PasteLine.app is ready."
