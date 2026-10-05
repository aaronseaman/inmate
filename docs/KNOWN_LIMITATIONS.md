# Known limitations

Plainly stated. Nothing below is hidden behind a "done" checkbox elsewhere.

## Platform verification (the big one)

- **No iOS build has been produced.** This environment is Linux without Xcode or the iOS SDK.
  The iOS layer (`iOS/FPod/*.swift`) was compiled only against hand-written stubs of the UIKit,
  SpriteKit and AVFoundation APIs it uses (`tools/ios-typecheck`). The stubs mirror Apple's
  signatures as closely as I could, but a real Xcode build may still surface errors (availability
  annotations, `@MainActor` isolation, Sendable checking under newer SDKs, deprecations).
- **Not run in the iOS Simulator or on a device.** Touch handling, safe-area layout on real
  notched devices, VoiceOver behavior, haptics, audio session behavior and frame rate are
  unverified on hardware.
- **Rendering on iOS is unverified.** All visual checks used the SVG renderer in `fpod-tool`, fed
  by the same display list, rasterized by Chromium. The CoreGraphics rasterizer in
  `iOS/FPod/Rasterizer.swift` and the SpriteKit node diffing in `Renderer.swift` have not been seen
  running. Text measurement in the core approximates SF Pro Rounded; real text may be slightly
  wider or narrower (labels shrink to fit on iOS).
- **Audio on iOS is unverified.** Every sound and music loop renders to WAV and passes level/loop
  tests, but nothing has been heard through `AVAudioEngine`.
- **Performance numbers are from Linux** (≈1.3 ms per frame for update + display list in a debug
  build). iPhone CPU/GPU costs, texture memory and chunk rasterization time are unknown.
- The generated Xcode project has an empty `DEVELOPMENT_TEAM` and placeholder bundle id
  `com.example.fpod`; signing must be set up by whoever builds it.

## Design deviations

- **Tap-only controls** (the user's request) replace the spec's floating joystick. Keyboard
  movement exists for development.
- **No SwiftUI.** All interface is drawn from the core display list so the same UI is tested
  headlessly; VoiceOver is served by a UIKit accessibility overlay.
- **One player character** (Jo Merritt). No character creation.

## Systems with stated gaps

- Yellow watch's "closer rounds" is a suspicion multiplier and movement restriction, not
  additional patrol routes. The red-watch constant observer is drawn from day-shift technicians;
  overnight the night officer's normal rounds apply.
- Outfit condition drops while running and is restored by washing; there are no authored stain or
  tear events.
- Cameras with nobody at the monitors record footage reviewed the next morning; they do not
  track a hidden player.
- Peers' daily routines are schedule-driven with authored events; there is modest seeded variation
  (movie night, soup day, common-area sweeps), not a generative social simulation.
- The art-sale price is fixed (4 credits via the chaplain's craft sale); the art minigame's score
  sets a nominal value shown to the player, not the payout.
- Card and domino opponents are deliberately basic; a competent player wins most but not all games.
- The map and dialogue are English only; there is no localization layer.

## Content honesty

- The facility, people, documents and procedures are fictional. Medication, restraint, seclusion,
  searches and weapons are abstracted; nothing is instructional.
- The escape ending is a fiction with explicit costs; it does not model real perimeter security.

## What would close the gaps

1. Build in Xcode 15+ for an iPhone simulator; fix any SDK-specific compile issues.
2. Run the opening day, a job minigame, the ending screen and a save/restore cycle on a device.
3. Profile a dense scene (dayroom at free time) with Instruments; check chunk rasterization.
4. Listen to all effects and loops on device speakers and headphones; adjust levels.
5. Exercise VoiceOver through the HUD, a fan, a document and a minigame.
