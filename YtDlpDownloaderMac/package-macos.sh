#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="YtDlpDownloaderMac"
DISPLAY_NAME="YtDlp Downloader"
CONFIGURATION="Release"
DERIVED_DATA="$PROJECT_DIR/build/DerivedData"
DIST_DIR="$PROJECT_DIR/dist"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_BACKGROUND_DIR="$DMG_ROOT/.background"
DMG_BACKGROUND="$DMG_BACKGROUND_DIR/installer-background.png"
DMG_BACKGROUND_SWIFT="$DIST_DIR/generate-dmg-background.swift"
APP_SOURCE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_TARGET="$DMG_ROOT/$DISPLAY_NAME.app"
DMG_PATH="$DIST_DIR/YtDlpDownloader-macOS-universal.dmg"
RW_DMG_PATH="$DIST_DIR/YtDlpDownloader-macOS-universal-rw.dmg"
ZIP_PATH="$DIST_DIR/YtDlpDownloader-macOS-universal.zip"
USE_FINDER_LAYOUT="${USE_FINDER_LAYOUT:-0}"

rm -rf "$DERIVED_DATA" "$DIST_DIR"
mkdir -p "$DMG_ROOT" "$DMG_BACKGROUND_DIR"

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
xcodebuild \
  -project "$PROJECT_DIR/YtDlpDownloaderMac.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -destination "generic/platform=macOS" \
  ARCHS="x86_64 arm64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

cp -R "$APP_SOURCE" "$APP_TARGET"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_TARGET"
fi

ln -s /Applications "$DMG_ROOT/Applications"

cat > "$DMG_BACKGROUND_SWIFT" <<'SWIFT'
import AppKit

let outputPath = CommandLine.arguments[1]
let size = NSSize(width: 760, height: 820)
let image = NSImage(size: size)

image.lockFocus()
NSColor.white.setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let dropRect = NSRect(x: 142, y: 102, width: 476, height: 300)
let dropPath = NSBezierPath(roundedRect: dropRect, xRadius: 4, yRadius: 4)
NSColor(calibratedRed: 0.88, green: 0.91, blue: 0.99, alpha: 1.0).setFill()
dropPath.fill()

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 380, y: 410))
arrowPath.line(to: NSPoint(x: 380, y: 340))
arrowPath.move(to: NSPoint(x: 318, y: 382))
arrowPath.line(to: NSPoint(x: 380, y: 318))
arrowPath.line(to: NSPoint(x: 442, y: 382))
arrowPath.lineWidth = 28
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
NSColor.white.setStroke()
arrowPath.stroke()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Unable to render DMG background")
}

try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT

/usr/bin/swift "$DMG_BACKGROUND_SWIFT" "$DMG_BACKGROUND"

if [ "$USE_FINDER_LAYOUT" = "1" ]; then
  hdiutil create "$RW_DMG_PATH" \
    -volname "$DISPLAY_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDRW

  MOUNT_DIR="/Volumes/$DISPLAY_NAME"
  hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
  hdiutil attach "$RW_DMG_PATH" -mountpoint "$MOUNT_DIR" -quiet
  cleanup_mount() {
    hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
  }
  trap cleanup_mount EXIT

  osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to POSIX file "$MOUNT_DIR" as alias
  set backgroundImage to POSIX file "$MOUNT_DIR/.background/installer-background.png" as alias
  open dmgFolder
  delay 1
  set dmgWindow to container window of dmgFolder
  set current view of dmgWindow to icon view
  set the bounds of dmgWindow to {160, 120, 920, 940}
  try
    set toolbar visible of dmgWindow to false
  on error
    try
      activate
      tell application "System Events"
        tell process "Finder"
          set frontmost to true
          keystroke "t" using {command down, option down}
        end tell
      end tell
    end try
  end try
  try
    set statusbar visible of dmgWindow to false
  end try
  try
    set sidebar width of dmgWindow to 0
  end try
  set viewOptions to the icon view options of dmgWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 150
  set background picture of viewOptions to backgroundImage
  set position of item "$DISPLAY_NAME.app" of dmgFolder to {380, 190}
  set position of item "Applications" of dmgFolder to {380, 600}
  update dmgFolder without registering applications
  delay 1
  try
    set toolbar visible of dmgWindow to false
  end try
  try
    set statusbar visible of dmgWindow to false
  end try
  delay 2
  try
    close dmgWindow
  end try
end tell
APPLESCRIPT

  if [ ! -f "$MOUNT_DIR/.DS_Store" ]; then
    echo "Finder did not create .DS_Store for the DMG layout; continuing with the default Finder layout." >&2
  fi

  bless --folder "$MOUNT_DIR" --openfolder "$MOUNT_DIR" >/dev/null 2>&1 || true

  cleanup_mount
  trap - EXIT

  hdiutil convert "$RW_DMG_PATH" -format UDZO -o "$DMG_PATH" -ov
  rm -f "$RW_DMG_PATH"
else
  hdiutil create "$DMG_PATH" \
    -volname "$DISPLAY_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO
fi

ditto -c -k --keepParent "$APP_TARGET" "$ZIP_PATH"

echo "Created:"
echo "$DMG_PATH"
echo "$ZIP_PATH"
