#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Codex 用量"
EXECUTABLE="CodexQuotaApp"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
DMG="$DIST/CodexQuota.dmg"
RW_DMG="$DIST/CodexQuota-rw.dmg"
ICONSET="$DIST/AppIcon.iconset"
APP_ICON="$RESOURCES/AppIcon.icns"
STAGE="$DIST/dmg-stage"
DMG_BACKGROUND="$STAGE/.background/background.png"
SELECTED_ICON_SOURCE="${SELECTED_ICON_SOURCE:-}"

cd "$ROOT"

detach_existing_codex_volumes() {
  mount | awk -F ' on ' '/\/Volumes\/Codex (额度|用量)/ {split($2, parts, " \\("); print parts[1]}' | while IFS= read -r mount_point; do
    [ -n "$mount_point" ] && hdiutil detach "$mount_point" >/dev/null 2>&1 || true
  done
}

build_with_swiftpm() {
  swift build -c release
  echo ".build/release/$EXECUTABLE"
}

build_with_swiftc_fallback() {
  local build_dir
  build_dir="$(mktemp -d /tmp/codexquota-build.XXXXXX)"

  swiftc \
    -parse-as-library \
    -emit-library \
    -static \
    -module-name CodexQuotaCore \
    -emit-module-path "$build_dir/CodexQuotaCore.swiftmodule" \
    Sources/CodexQuotaCore/QuotaModels.swift \
    Sources/CodexQuotaCore/StatusParser.swift \
    Sources/CodexQuotaCore/LocalCodexUsageReader.swift \
    Sources/CodexQuotaCore/OfficialCodexUsageReader.swift \
    -o "$build_dir/libCodexQuotaCore.a"

  swiftc \
    -O \
    -I "$build_dir" \
    -L "$build_dir" \
    -lCodexQuotaCore \
    Sources/CodexQuotaApp/AppState.swift \
    Sources/CodexQuotaApp/ColorSupport.swift \
    Sources/CodexQuotaApp/FloatingViews.swift \
    Sources/CodexQuotaApp/FloatingWindowController.swift \
    Sources/CodexQuotaApp/GlassViews.swift \
    Sources/CodexQuotaApp/SettingsView.swift \
    Sources/CodexQuotaApp/main.swift \
    -o "$build_dir/$EXECUTABLE"

  echo "$build_dir/$EXECUTABLE"
}

if BUILD_OUTPUT="$(build_with_swiftpm 2>/tmp/codexquota-swiftpm.log)" && [ -f "$BUILD_OUTPUT" ]; then
  BUILT_EXECUTABLE="$BUILD_OUTPUT"
else
  echo "swift build failed; falling back to direct swiftc build."
  cat /tmp/codexquota-swiftpm.log
  BUILT_EXECUTABLE="$(build_with_swiftc_fallback)"
fi

rm -rf "$APP" "$DMG" "$RW_DMG" "$ICONSET" "$STAGE"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BUILT_EXECUTABLE" "$MACOS/$EXECUTABLE"

mkdir -p "$ICONSET"
python3 - "$ICONSET" "$SELECTED_ICON_SOURCE" <<'PY'
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

out = Path(sys.argv[1])
source = Path(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else None

if source is not None and source.is_file():
    src = Image.open(source).convert("RGBA")
    side = min(src.size)
    left = (src.width - side) // 2
    top = (src.height - side) // 2
    base = src.crop((left, top, left + side, top + side)).resize((1024, 1024), Image.LANCZOS)
else:
    base = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    draw = ImageDraw.Draw(base)
    for radius, alpha in [(430, 42), (340, 58), (250, 70)]:
        layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        d.ellipse((512-radius, 512-radius, 512+radius, 512+radius), outline=(37, 231, 255, alpha), width=16)
        base = Image.alpha_composite(base, layer.filter(ImageFilter.GaussianBlur(4)))
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle((170, 170, 854, 854), radius=188, fill=(3, 10, 22, 235), outline=(37, 231, 255, 190), width=8)
    draw.arc((250, 250, 774, 774), -86, 190, fill=(37, 231, 255, 255), width=52)
    draw.arc((316, 316, 708, 708), -86, 88, fill=(168, 85, 247, 255), width=44)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 250)
    except Exception:
        font = ImageFont.load_default()
    text = "C"
    bbox = draw.textbbox((0, 0), text, font=font)
    draw.text(((1024-(bbox[2]-bbox[0]))/2, (1024-(bbox[3]-bbox[1]))/2-28), text, font=font, fill=(245, 255, 252, 255))

sizes = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
for name, size in sizes:
    base.resize((size, size), Image.LANCZOS).save(out / name)
PY
iconutil -c icns "$ICONSET" -o "$APP_ICON"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE</string>
  <key>CFBundleIdentifier</key>
  <string>com.codexquota.desktop</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

chmod +x "$MACOS/$EXECUTABLE"
touch "$APP"

mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/$APP_NAME.app"
cp "$APP_ICON" "$STAGE/.VolumeIcon.icns"
SetFile -a C "$STAGE/$APP_NAME.app" || true
ln -s /Applications "$STAGE/Applications"
mkdir -p "$(dirname "$DMG_BACKGROUND")"
python3 - "$DMG_BACKGROUND" <<'PY'
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

out = Path(sys.argv[1])
width, height = 760, 460
img = Image.new("RGBA", (width, height), (5, 11, 16, 255))

glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
d = ImageDraw.Draw(glow)
d.ellipse((-130, -120, 360, 360), fill=(126, 246, 197, 72))
d.ellipse((410, -150, 910, 350), fill=(182, 108, 255, 56))
d.ellipse((250, 230, 860, 640), fill=(34, 211, 238, 42))
img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(55)))

draw = ImageDraw.Draw(img)
draw.rounded_rectangle((28, 28, width - 28, height - 28), radius=34, outline=(37, 231, 255, 130), width=2)
try:
    title_font = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 36)
    body_font = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 18)
except Exception:
    title_font = body_font = ImageFont.load_default()

title = "Codex 用量"
subtitle = "拖动到 Applications 完成安装"

tb = draw.textbbox((0, 0), title, font=title_font)
draw.text(((width - (tb[2] - tb[0])) / 2, 56), title, font=title_font, fill=(245, 255, 252, 255))
sb = draw.textbbox((0, 0), subtitle, font=body_font)
draw.text(((width - (sb[2] - sb[0])) / 2, 106), subtitle, font=body_font, fill=(214, 226, 231, 225))
arrow_y = 246
draw.line((316, arrow_y, 444, arrow_y), fill=(126, 246, 197, 205), width=6)
draw.polygon([(444, arrow_y), (420, arrow_y - 16), (420, arrow_y + 16)], fill=(126, 246, 197, 225))

img.convert("RGB").save(out)
PY
SetFile -a C "$STAGE" || true

detach_existing_codex_volumes
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$RW_DMG"

DEVICE="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen | awk '/Apple_HFS/ {print $1; exit}')"
VOLUME="$(diskutil info "$DEVICE" | awk -F': *' '/Mount Point/ {print $2; exit}')"

osascript <<APPLESCRIPT
tell application "Finder"
  set bgPic to POSIX file "$VOLUME/.background/background.png" as alias
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {160, 120, 920, 580}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set background picture of viewOptions to bgPic
    set position of item "$APP_NAME.app" of container window to {218, 250}
    set position of item "Applications" of container window to {542, 250}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -f "$RW_DMG"

echo "Created $APP"
echo "Created $DMG"
