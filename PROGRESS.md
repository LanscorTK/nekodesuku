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
- [ ] Edge climbing (deferred to later phase)

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

## Phase 5: Polish & Extras
- [x] Multi-monitor support (per-pet screen detection, cross-screen walking)
- [x] Cat naming (hover tooltip, right-click rename, persisted)
- [x] Settings window (scale, speed, gravity, activity level sliders)
- [ ] Sound effects (meow/purr with volume control)
- [ ] Seasonal behaviors
