# F-Pod

A tap-only, top-down 2D stealth adventure about institutional life, for iPhone (landscape).
You play Jo Merritt, a patient-prisoner on F-Pod of a fictional federal forensic psychiatric
center, awaiting a competency evaluation with a chart that is wrong in at least one important
way. Get through the days, keep your people close, prove the record wrong — and choose how it ends.

Darkly comic, humane, non-graphic. Searches, seclusion and restraint appear only as short
transitions, icons and aftermath. No realistic doses, procedures, weapons or security details.

## What's here

| | |
|---|---|
| Engine | Swift. Platform-independent core (`FPodCore`) + thin SpriteKit/UIKit app (`iOS/FPod`) |
| Content | 12 main chapters (3 finale variants), 29 side errands, 208 interactions, 24 choices, 29 trades |
| People | 14 peers, 15 staff, 2 visitors — each with routines, wants and a boundary |
| World | 200×140-tile campus, 10 districts, 91 zones, 76 doors, 12 cameras, 41 hiding places, 58 stashes |
| Play | 7 jobs, 19 minigames (chess with full rules, dominoes, crazy eights …), 4 vehicles + van run |
| Endings | Conditional release · A better placement (advocacy) · Through the trees (escape) |
| Tests | 91 XCTest cases, including end-to-end playthroughs of all three endings |

See `docs/FEATURE_MATRIX.md` for the spec-by-spec checklist, `docs/KNOWN_LIMITATIONS.md`
for what has *not* been verified, `docs/LICENSES.md` for the asset inventory, `docs/GRAPHICS_HANDOFF.md` for art contributors and
`docs/STYLE_GUIDE.md` for the art, audio and writing rules.

## Controls (tap only)

| Do | How |
|---|---|
| Walk | Tap the floor. Paths go around walls and through doors you may use. |
| Run once | Double-tap the floor. Or toggle **Run** (noisy indoors). |
| Sneak | Toggle **Sneak**: quiet (not invisible); shows staff vision cones. |
| Use / talk | Tap a person or object: you walk over and a fan of options opens. The big round button uses whatever is outlined in front of you. |
| Inventory · map · journal · menu | Top-right buttons. |
| Park equipment | The **Park** button replaces Run/Sneak while pushing a cart. |
| Minigames | Each explains its taps first; the clock pauses while you play. Assist mode (Settings) can auto-pass any of them. |

Settings: left-handed layout, reduced motion, captions, icon labels, separate music / effects /
voice volumes, zoom, haptics, difficulty (gentle/standard/sharp), clock speed, betting on/off, always-on
vision cones, assist mode. Help → *Controls & icons* explains every badge (shape **and** color).

Simulator/hardware keyboard (development convenience): WASD/arrows move, Space/E/Return interact,
R run, C sneak, I inventory, M map, J journal, Esc menu, F1 developer menu (debug builds only).

## Build and run (iOS)

Requirements: Xcode 15 or later, iOS 16+ device or simulator. **This repository has not yet been
built with Xcode** — see *Known limitations*.

1. `python3 tools/gen_xcodeproj.py` (regenerates `FPod.xcodeproj` from the source tree; rerun after adding files).
2. Open `FPod.xcodeproj`, select the **FPod** target → *Signing & Capabilities*: choose your team and
   change the bundle identifier (`com.example.fpod`).
3. Pick an iPhone simulator or device; Run. Landscape only.

The app target compiles `Sources/FPodCore/**` directly together with `iOS/FPod/*.swift`; there is
no package dependency to resolve. Saves live in `Application Support/FPod/` (`save.json`,
`save.json.bak`, `prefinale.json`); settings in `UserDefaults` (`fpod.settings.v1`).

## Develop on any machine (Swift 6 toolchain)

```sh
swift build                      # core library + dev tool
swift test                       # 91 tests (≈45 s in debug)
swift run fpod-tool scenarios    # list snapshot scenarios
swift run fpod-tool stats        # content counts
swift run fpod-tool items        # every item's sources and uses
swift run fpod-tool objects      # zone/object/spot/door reference for authors
swift run fpod-tool audio out/audio   # render every effect and music loop to WAV
tools/snap.sh pod mop chess ending    # render scenarios to out/*.png (needs Node + Playwright Chromium)
```

`tools/snap.sh` draws the *same display list* the iOS renderer consumes, through an SVG renderer,
then rasterizes it with Chromium. Snapshot names: any key from `fpod-tool scenarios`, or
`mg-<minigame>[@seconds]` to start a minigame and let its bot play for a while.

`tools/ios-typecheck/` type-checks the iOS layer on Linux against hand-written stubs of the UIKit,
SpriteKit and AVFoundation APIs it uses (`cd tools/ios-typecheck && swift build`). It catches
Swift errors in the app layer; it is **not** an iOS build.

Developer menu (debug builds only: Pause → Developer, or F1): clock advance, sleep, teleport to
each district, credits, trust, suspicion, watch levels, outfit condition, all outfits/keys, quest
advance, jobs, and seeded story scenarios (lawyer met, review prep, discharge plan, advocacy,
escape night).

## How it's built

```
Sources/FPodCore/
  Util/          math, seeded RNG, heap, palette
  World/         tile map builder, campus geometry checks, A* navigation, line of sight, noise
  Content/       data: items, cast, schedule, campus, jobs, trades, interactions, choices, quests, docs
    Story/       main arc, side arc, item stories (authored content)
  Sim/           Game: clock, access, player, NPC AI, perception, inventory/ledger, capture,
                 script engine (Cond/Effect), systems (vehicles, meals, staging), transitions
  Minigames/     shared kit + 19 games (each with rules, scoring, a test bot)
  Presentation/  HUD, menus, minigame overlay, input → display list (RenderItems) + hit regions
    Art/         vector "paper-cut" drawings for tiles, props, figures, icons, chess, vehicles
  Audio/         procedural DSP: effects, mumbles, music loops
  Persistence/   versioned saves with checksum, atomic write, backup
iOS/FPod/        SpriteKit scene, CoreGraphics rasterizer + texture cache, AVAudioEngine player,
                 haptics, VoiceOver overlay, save store
Sources/FPodTool dev CLI (snapshots, audio, audits)    Tests/  XCTest suites
```

- **Simulation is renderer-free.** `Game.update(dt:)` advances the world; `Game.buildFrame()`
  returns a display list plus hit regions and accessibility elements. iOS rasterizes it; tests
  and tools read it directly.
- **Content is data.** Interactions (`Target`, `Cond`, `[Effect]`), choices, quests (stages with
  completion conditions, approaches, recovery notes), trades (fixed quotes), stash stock and
  appointments are declarative tables. Stable string raw values are persisted — never rename one;
  add a case.
- **Events** (`GameEvent`) connect consequences (zone entered, shift done, appointment kept …)
  to story hooks without circular callbacks.
- **Saves** are a JSON envelope (version, checksum over the exact body bytes, label) written
  atomically with a `.bak`. Fields added after v1 are optional, so older saves still load
  (`PersistenceTests`).

## Authoring content

Add an interaction to the relevant table (`Content/Systems.swift`, `Content/Story/*.swift`):
`InteractionDef("unique.id", .npc(.dutch) | .object("id") | .kind(.bunk), icon, "Caption", when: Cond, …, [Effect])`.
Use `swift run fpod-tool objects` for valid object and spot IDs. Run `swift test`: the suites check
that every item has a source and a use, every outfit has two routes, every choice can be reached,
every minigame obeys the contract, and all three endings can be finished.
