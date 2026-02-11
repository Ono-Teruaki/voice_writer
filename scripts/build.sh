#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="VoiceWriter"
BUILD_DIR="$PROJECT_DIR/.build"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

EXECUTABLE="$BUILD_DIR/release/$APP_NAME"

if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ Build failed: executable not found at $EXECUTABLE"
    exit 1
fi

echo "📦 Creating app bundle..."

# Clean previous bundle
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Ad-hoc code sign
echo "🔏 Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ App bundle created at: $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
echo ""
echo "⚠️  Don't forget to grant permissions in System Settings:"
echo "   - Privacy & Security > Microphone > VoiceWriter"
echo "   - Privacy & Security > Accessibility > VoiceWriter"
