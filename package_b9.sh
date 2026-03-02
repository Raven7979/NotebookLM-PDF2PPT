#!/bin/bash
set -e
APP_BUNDLE_SRC="NotePDF 2 PPT.app"
APP_BUNDLE_DEST="NotePDF 2 PPT.app"
SRC_APP_PATH="/Users/Ravenlei/Work/Vibe coding/Notebooklm 2 PPTX/NotePDF2PPT_v2/1. 前端最终版 v1.0/Mac_App_Project/build_output/Build/Products/Release/${APP_BUNDLE_SRC}"
STAGING_DIR="DMG_Staging"
OUTPUT_DIR="/Users/Ravenlei/Work/Vibe coding/Notebooklm 2 PPTX/NotePDF2PPT_v2/3. 打包输出 v1.0"
FINAL_DMG="${OUTPUT_DIR}/NotePDF2PPT_v1.1_b0.dmg"
TEMP_DMG="temp_b0.dmg"
VOL_NAME="NotePDF 2 PPT"

rm -rf "$STAGING_DIR"; mkdir "$STAGING_DIR"
cp -R "$SRC_APP_PATH" "$STAGING_DIR/$APP_BUNDLE_DEST"
ln -s /Applications "$STAGING_DIR/Applications"
ICON_PATH="${STAGING_DIR}/${APP_BUNDLE_DEST}/Contents/Resources/AppIcon.icns"

rm -f "$TEMP_DMG"
hdiutil create -srcfolder "$STAGING_DIR" -volname "$VOL_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW "$TEMP_DMG"

MOUNT_PLIST=$(hdiutil attach -readwrite -noverify -plist "$TEMP_DMG")
MOUNT_POINT=$(echo "$MOUNT_PLIST" | grep -A1 'mount-point' | tail -n1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$MOUNT_POINT/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT_POINT/.VolumeIcon.icns"
    SetFile -a V "$MOUNT_POINT/.VolumeIcon.icns"
    SetFile -a C "$MOUNT_POINT"
fi
DEVICE=$(echo "$MOUNT_PLIST" | grep -A1 'dev-entry' | head -n2 | tail -n1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
hdiutil detach "$DEVICE"

rm -f "$FINAL_DMG"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"

rm -rf "$STAGING_DIR" "$TEMP_DMG"
echo "✅ Done! $FINAL_DMG"
ls -lh "$FINAL_DMG"
