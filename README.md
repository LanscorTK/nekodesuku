# NekoDeskuToppu

A macOS desktop pet app powered by pixel art kittens from the [Sprout Lands](https://cupnooble.itch.io/sprout-lands-asset-pack) asset pack.

16x16 sprite cats live on your screen — walking, sleeping, climbing walls, and being adorable.

## Features

**Cats**
- 13 cat breeds with multiple color variants each
- Unlimited cats on screen simultaneously, each with independent behavior
- Give your cats custom names (hover to see, right-click to rename)

**Behaviors**
- Idle sitting with subtle breathing animation
- Walking left/right with smooth state transitions
- Sleeping (8-15 seconds, sometimes yawns on waking)
- Meowing, yawning, washing, scratching
- Edge climbing: cats walk to screen edge, climb up the wall, stroll along the top, then jump down
- Zoomies: sudden back-and-forth dashing at 2x speed
- Chase bug: walk toward an imaginary bug, swat it, eat it
- Stretching: stand on hind legs, then yawn

**Interactions**
- **Drag** to pick up and move your cat
- **Click** to poke (50% meow, 30% hiss, 20% stand up)
- **Long press** (>1s) to pet (cat washes contentedly, yawns when you let go)
- Cats occasionally follow your mouse cursor, then swat at it

**Settings**
- Adjustable size (3x-10x pixel scale)
- Walk speed, gravity strength, activity level sliders
- All preferences saved automatically across restarts

**System**
- Menu bar app (no dock icon)
- Multi-monitor support: cats detect which screen they're on, walk between screens
- Launch at login option
- Check for updates via GitHub Releases
- Universal binary (Intel + Apple Silicon)
- macOS 13+

## Download & Install

1. Download `NekoDeskuToppu.dmg` from [Releases](../../releases)
2. Open the DMG, drag **NekoDeskuToppu** into **Applications**
3. First launch requires bypassing macOS Gatekeeper (unsigned app):

**Option A (recommended):**

```bash
xattr -cr /Applications/NekoDeskuToppu.app
```

Then double-click to open.

**Option B:**
Right-click the app -> Open -> Click "Open" in the dialog.

> This is a standard macOS security prompt for unsigned apps. You only need to do this once.

## Usage

| Action | Effect |
|--------|--------|
| Drag | Pick up and move the cat |
| Click | Poke (meow / hiss / stand up) |
| Hold >1s | Pet the cat |
| Right-click | Context menu (choose cat, rename, remove) |
| Hover | Show cat's name |
| Menu bar | Add/remove cats, settings, check for updates |

## Build from Source

Requires macOS 13+, Swift 5.9+ (Xcode Command Line Tools), and the [Kittens pack](https://cupnooble.itch.io/sprout-lands-asset-pack) assets.

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

### Development

```bash
bash build.sh    # Build bare binary
bash run.sh      # Auto-detect assets & run
```

### Regenerate App Icon

```bash
swift make_icon.swift
```

## Assets

This app uses the "Kittens pack" pixel art assets by [Cup Nooble](https://cupnooble.itch.io/sprout-lands-asset-pack). The pack is not included in this repository.
