#!/bin/bash
# Notarize NekoDeskuToppu for distribution
# Prerequisites:
#   1. Apple Developer account ($99/year) — https://developer.apple.com
#   2. Developer ID Application certificate installed in Keychain
#   3. App-specific password — https://appleid.apple.com → Sign-In and Security → App-Specific Passwords
#
# Usage:
#   export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   export APPLE_ID="your@email.com"
#   export TEAM_ID="YOURTEAMID"
#   export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
#   bash notarize.sh

set -e
cd "$(dirname "$0")"

DMG="NekoDeskuToppu.dmg"

if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$APP_PASSWORD" ]; then
    echo "Error: Set APPLE_ID, TEAM_ID, and APP_PASSWORD environment variables."
    echo "See comments at top of this script for setup instructions."
    exit 1
fi

if [ ! -f "$DMG" ]; then
    echo "Error: $DMG not found. Run 'bash bundle.sh && bash make_dmg.sh' first."
    exit 1
fi

echo "Submitting $DMG for notarization..."
xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG"

echo "Done! $DMG is notarized and ready for distribution."
echo "Verify with: spctl --assess --type open --context context:primary-signature -v $DMG"
