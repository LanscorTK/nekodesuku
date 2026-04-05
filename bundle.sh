#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="NekoDeskuToppu.app"

# Auto-detect Kittens pack location
PACK="${1:-}"
if [ -z "$PACK" ]; then
    for candidate in \
        "./Kittens pack" \
        "$HOME/Downloads/Kittens pack" \
        "$HOME/Desktop/Kittens pack"; do
        if [ -d "$candidate" ]; then
            PACK="$candidate"
            break
        fi
    done
fi

if [ -z "$PACK" ]; then
    echo "Error: Kittens pack not found. Pass the path as argument:"
    echo "  bash bundle.sh \"/path/to/Kittens pack\""
    exit 1
fi

echo "Using assets: $PACK"

# Compile
echo "Compiling..."
swiftc -O -o NekoDeskuToppu main.swift

# Build .app bundle
echo "Building $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp NekoDeskuToppu "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"

# Copy icon if available
if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "$APP/Contents/Resources/"
fi

# Copy assets (GIFs only, exclude source art)
echo "Copying assets..."
rsync -a \
    --exclude='*.aseprite' \
    --exclude='*.png' \
    --exclude='*.gpl' \
    --exclude='.DS_Store' \
    "$PACK/" "$APP/Contents/Resources/Kittens pack/"

# Ad-hoc code sign
echo "Signing..."
codesign --force --deep --sign - "$APP"

# Report
SIZE=$(du -sh "$APP" | cut -f1)
echo "Done! $APP ($SIZE)"
echo "  Open with: open $APP"
