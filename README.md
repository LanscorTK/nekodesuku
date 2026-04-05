# NekoDeskuToppu

A macOS desktop pet app powered by pixel art kittens.

16x16 sprite cats live on your screen — walking, sleeping, meowing, and being adorable.

## Requirements

- macOS 13+
- Swift 5.9+ (Xcode Command Line Tools)
- [Kittens pack](https://cupnooble.itch.io/sprout-lands-asset-pack) assets

## Install (App Bundle)

```bash
# Build .app bundle (auto-detects Kittens pack in ~/Downloads)
bash bundle.sh

# Or specify the asset path
bash bundle.sh "/path/to/Kittens pack"

# Launch
open NekoDeskuToppu.app
```

To create a distributable DMG/zip:

```bash
bash make_dmg.sh
```

## Development

```bash
# Build bare binary
bash build.sh

# Run (auto-detects Kittens pack in ~/Downloads)
bash run.sh

# Or run manually with a custom path
./NekoDeskuToppu "/path/to/Kittens pack"
```

## App Icon

To regenerate the app icon from sprites:

```bash
swift make_icon.swift
```

## Usage

- **Drag** the cat to move it around
- **Right-click** to open the menu (choose cat, color variant, quit)
- The cat walks along the bottom of your screen and randomly sits, sleeps, meows, yawns, washes, and scratches

## Assets

This app uses the "Kittens pack" pixel art assets. The pack is not included — please purchase it from the original creator.
