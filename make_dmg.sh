#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="NekoDeskuToppu.app"
DMG="NekoDeskuToppu.dmg"
STAGING="dmg_staging"
VOL_NAME="NekoDeskuToppu"

if [ ! -d "$APP" ]; then
    echo "Error: $APP not found. Run 'bash bundle.sh' first."
    exit 1
fi

echo "Creating DMG..."
rm -rf "$STAGING" "$DMG"
mkdir "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Create DMG with custom window size
hdiutil create -volname "$VOL_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDRW \
    "${DMG}.rw"

# Mount and configure appearance
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "${DMG}.rw" | grep "$VOL_NAME" | awk '{print $3}')
if [ -n "$MOUNT_DIR" ]; then
    # Set Finder window appearance via AppleScript
    osascript <<EOF
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 720, 400}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set position of item "$APP" of container window to {130, 140}
        set position of item "Applications" of container window to {390, 140}
        close
    end tell
end tell
EOF
    sync
    hdiutil detach "$MOUNT_DIR" -quiet
fi

# Convert to compressed read-only DMG
hdiutil convert "${DMG}.rw" -format UDZO -o "$DMG"
rm -f "${DMG}.rw"

rm -rf "$STAGING"

SIZE=$(du -sh "$DMG" | cut -f1)
echo "Done! $DMG ($SIZE)"

# Also create zip
ZIP="NekoDeskuToppu.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
ZSIZE=$(du -sh "$ZIP" | cut -f1)
echo "Also: $ZIP ($ZSIZE)"
