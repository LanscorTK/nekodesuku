# NekoDeskuToppu

A macOS desktop pet app powered by pixel art kittens.

16x16 sprite cats live on your screen — walking, sleeping, meowing, and being adorable.

## Requirements

- macOS 13+
- Swift 5.9+ (Xcode Command Line Tools)
- [Kittens pack](https://cupnooble.itch.io/sprout-lands-asset-pack) assets

## Download & Install

1. 从 [Releases](../../releases) 页面下载最新的 `NekoDeskuToppu.dmg`
2. 打开 DMG，将 **NekoDeskuToppu** 拖入 **Applications**
3. 首次打开需要解除 macOS 安全限制（因为没有 Apple 开发者签名）：

**方法一（推荐）：**

```bash
xattr -cr /Applications/NekoDeskuToppu.app
```

然后双击打开即可。

**方法二：**
右键点击 app → 选择「打开」→ 在弹出的对话框中再次点击「打开」。

> 这是 macOS 对未签名 app 的正常安全提示，只需操作一次。

## Build from Source

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
- **Click** to poke the cat (it'll meow, hiss, or stand up)
- **Long press** (hold >1s) to pet the cat
- **Right-click** to open the menu (choose cat, color variant, quit)
- **Menu bar 🐱** to add/remove cats, change variants, check for updates
- Cats walk, sleep, meow, wash, scratch, and occasionally go on zoomies

## Assets

This app uses the "Kittens pack" pixel art assets. The pack is not included — please purchase it from the original creator.
