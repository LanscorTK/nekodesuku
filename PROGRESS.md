# NekoDeskuToppu - Progress

## Phase 1: Project Foundation ✅
- [x] `.gitignore`
- [x] `README.md` with build & usage instructions
- [x] `build.sh` compile script
- [x] `run.sh` auto-detect assets & run
- [x] Initial commit

## Phase 2: Core UX Improvements ✅
- [x] Idle animation (subtle breathing bob via sine wave)
- [x] Smooth state transitions (0.15s pause before new animation starts)
- [x] Gravity / dock to bottom (cat drifts back down after being dragged)
- [x] Menu bar icon (NSStatusItem 🐱) with add/remove/change cat
- [x] Multiple cats on screen simultaneously (PetInstance refactor)

## Phase 3: Personality & Interaction ✅
- [x] Click reactions (meow_stand 50%, hiss 30%, on_hind_legs 20%)
- [x] Mouse follow (20% chance, 8-dir walk toward cursor, paw_att on arrival)
- [x] Petting (hold >1s → wash_lie loop, release → yawn transition)
- [x] Random events: zoomies, chase bug (walk→paw→eat), stretch (hind_legs→yawn)
- [x] Edge climbing (20% chance at screen edge → climb up → walk top → fall)

## Phase 4: App Packaging ✅
- [x] `.app` bundle structure (bundle.sh)
- [x] Bundle Kittens pack assets into Resources (GIF-only rsync)
- [x] App icon from pixel cat sprites (make_icon.swift)
- [x] Launch at login option (SMAppService, menu bar toggle)
- [x] DMG / zip packaging (make_dmg.sh)

## Phase 4.5: Distribution Readiness ✅
- [x] Universal binary (ARM64 + x86_64 via lipo)
- [x] App versioning (CFBundleShortVersionString 1.0.0, shown in menu)
- [x] Settings persistence (UserDefaults: cat count, variants, colors survive restart)
- [x] Check for Updates menu item (GitHub Releases API, no dependencies)
- [x] Asset validation on startup (alert dialog if Kittens pack missing)
- [x] Code signing scaffolding (entitlements.plist, CODESIGN_IDENTITY in bundle.sh)
- [x] Notarization script (notarize.sh with credential placeholders)
- [x] DMG appearance polish (icon positioning, custom window size)
- [ ] Developer ID signing + notarization (requires Apple Developer account)

## Phase 5: Polish & Extras ✅
- [x] Multi-monitor support (per-pet screen detection, cross-screen walking)
- [x] Cat naming (hover tooltip, right-click rename, persisted)
- [x] Pixel cat menu bar icon (from Kittens pack GIF, template image)
- [x] Cat breed display names (Gray, Silver, Black, Orange, etc.)
- [x] Fix Cat 8-13 not loading (no subfolder variant support)
- [x] Summon All Cats (⌘S, bring all cats to mouse position)

## Phase 6: Main Panel GUI ✅
- [x] Unified panel window (Open Panel ⌘,)
- [x] My Cats list (pixel thumbnails, name, breed, rename/delete)
- [x] Add a Cat grid (13 breeds with pixel art previews, click to add)
- [x] Click cat in list → select → right grid switches to "Change Breed" mode
- [x] Settings integrated (scale, speed, gravity, activity sliders)
- [x] Replaced standalone Settings window

## Phase 6.5: UX Polish ✅
- [x] Right-click "Do…" submenu (Sleep, Meow, Yawn, Wash, Scratch, Zoomies)
- [x] Right-click "Open Panel…" shortcut
- [x] Panel UI alignment and spacing fixes
- [x] Variant color picker in panel (click breed → shows all color variants)
- [x] Panel buttons: + Random, Summon, Rm All
- [x] Menu bar: Remove All Cats option
- [x] Removed Launch at Login from menu
- [x] Codex review fixes (icon path, menu fallback)

## Phase 7: Window Awareness ✅
- [x] WindowTracker (CGWindowListCopyWindowInfo, 0.5s refresh)
- [x] Cats land on app window tops instead of only screen bottom
- [x] Walk off window edge → fall to next surface
- [x] Window moved/closed → cat falls naturally
- [x] Settings toggle: Window Awareness on/off (persisted)

## Phase 8: Auto-Sleep & Statistics ✅
- [x] Auto-sleep: cats fall asleep after N minutes of no interaction (default 5m, configurable)
- [x] Per-cat statistics: companion time, clicks, pettings, distance walked, sleep time
- [x] Stats displayed in panel when cat is selected
- [x] Stats auto-saved every 60s, persisted across restarts
- [x] Settings tooltips on hover for all controls

## Backlog
- [ ] Cat-to-cat interactions (paw_att, wash when near each other)
- [ ] Feeding (drop treat from menu → cats run to eat)
- [ ] Time awareness (cats sleep more at night)
- [ ] Mouse curiosity (cat watches cursor, startled by fast movement)
- [ ] Mood system (interaction frequency affects behavior)
- [ ] Sound effects (meow/purr with volume control)
- [ ] Seasonal behaviors
- [ ] Developer ID signing + notarization (requires Apple Developer account)
