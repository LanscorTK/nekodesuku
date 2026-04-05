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

## Phase 5: Polish & Extras
- [ ] Settings window (scale, speed, behavior tuning)
- [ ] Cat naming (hover tooltip)
- [ ] Sound effects (meow/purr with volume control)
- [ ] Multi-monitor support
- [ ] Seasonal behaviors
