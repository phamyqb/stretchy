#!/bin/bash
# Dùng: ./build.sh           -> build ra build/Stretchy.app
#       ./build.sh install   -> build + copy vào /Applications + mở app
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Stretchy.app"

echo "▶ Building (release)…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Stretchy"

echo "▶ Packaging $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Stretchy"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns" || true

# Ký ad-hoc để macOS chạy được app local (và để "Khởi động cùng macOS" hoạt động)
codesign --force --deep --sign - "$APP"

echo "✓ Xong: $APP"

if [ "${1:-}" = "install" ]; then
  pkill -x Stretchy 2>/dev/null || true
  rm -rf /Applications/Stretchy.app
  cp -R "$APP" /Applications/Stretchy.app
  open /Applications/Stretchy.app
  echo "✓ Đã cài vào /Applications và mở Stretchy"
fi
