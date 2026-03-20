#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load version
source "$ROOT_DIR/version.env"

APP_NAME="GPUBar"
APP_BUNDLE="$ROOT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

echo "==> Building $APP_NAME v$MARKETING_VERSION ($BUILD_NUMBER)..."

# Build release binary (arm64 only)
swift build -c release --package-path "$ROOT_DIR"

BINARY="$ROOT_DIR/.build/release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi

# Clean previous bundle
rm -rf "$APP_BUNDLE"

# Create .app structure
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"
mkdir -p "$CONTENTS/Frameworks"

# Copy binary
cp "$BINARY" "$CONTENTS/MacOS/$APP_NAME"

# Copy icon if it exists
if [ -f "$ROOT_DIR/Resources/Icon.icns" ]; then
    cp "$ROOT_DIR/Resources/Icon.icns" "$CONTENTS/Resources/Icon.icns"
    ICON_ENTRY="    <key>CFBundleIconFile</key>
    <string>Icon</string>"
else
    echo "WARN: No Icon.icns found in Resources/, skipping icon"
    ICON_ENTRY=""
fi

# Embed Sparkle.framework if available
SPARKLE_FRAMEWORK=$(find "$ROOT_DIR/.build" -name "Sparkle.framework" -type d 2>/dev/null | head -1)
if [ -n "$SPARKLE_FRAMEWORK" ]; then
    echo "==> Embedding Sparkle.framework"
    cp -R "$SPARKLE_FRAMEWORK" "$CONTENTS/Frameworks/"
fi

# SUPublicEDKey — set this to your actual Sparkle EdDSA public key
# Generate with: .build/artifacts/sparkle/Sparkle/bin/generate_keys
SU_PUBLIC_KEY="${SU_PUBLIC_ED_KEY:-}"
if [ -n "$SU_PUBLIC_KEY" ]; then
    SPARKLE_ENTRIES="    <key>SUPublicEDKey</key>
    <string>$SU_PUBLIC_KEY</string>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/OWNER/gpubar/main/appcast.xml</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>"
else
    SPARKLE_ENTRIES="    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/OWNER/gpubar/main/appcast.xml</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>"
fi

# Generate Info.plist with version from version.env
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.gpubar.app</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleShortVersionString</key>
    <string>$MARKETING_VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
$ICON_ENTRY
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>CFBundleURLName</key>
            <string>com.gpubar.app</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>gpubar</string>
            </array>
        </dict>
    </array>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
$SPARKLE_ENTRIES
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

# Add rpath so the binary can find embedded frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "$CONTENTS/MacOS/$APP_NAME" 2>/dev/null || true

# Ad-hoc codesign (sign frameworks first, then the bundle)
if [ -d "$CONTENTS/Frameworks/Sparkle.framework" ]; then
    codesign --force --sign - "$CONTENTS/Frameworks/Sparkle.framework"
fi
codesign --force --sign - "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
echo "    Version: $MARKETING_VERSION ($BUILD_NUMBER)"
echo "    Size: $(du -sh "$APP_BUNDLE" | cut -f1)"
echo ""
echo "    Install: cp -r $APP_BUNDLE /Applications/"
