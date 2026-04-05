#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="NekoDeskuToppu.app"
DMG="NekoDeskuToppu.dmg"
STAGING="dmg_staging"

if [ ! -d "$APP" ]; then
    echo "Error: $APP not found. Run 'bash bundle.sh' first."
    exit 1
fi

echo "Creating DMG..."
rm -rf "$STAGING" "$DMG"
mkdir "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "NekoDeskuToppu" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG"

rm -rf "$STAGING"

SIZE=$(du -sh "$DMG" | cut -f1)
echo "Done! $DMG ($SIZE)"

# Also create zip
ZIP="NekoDeskuToppu.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
ZSIZE=$(du -sh "$ZIP" | cut -f1)
echo "Also: $ZIP ($ZSIZE)"
