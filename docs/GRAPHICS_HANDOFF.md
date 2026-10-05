# Graphics handoff

For anyone polishing the art in parallel with ongoing gameplay work. Read `STYLE_GUIDE.md` for
the look; this page covers the mechanics and the rules that keep the iOS app and the tests
working.

## Where the art lives

| File | Draws |
|---|---|
| `Sources/FPodCore/Util/Color.swift` | `Palette` tokens: eight anchors, status colors, world tones and accents (values in `STYLE_GUIDE.md`). |
| `Presentation/Art/ArtLibrary.swift` | `ArtKey → Drawing` dispatch; UI art: panels, buttons, badges, bubbles, markers, `named(...)` extras. |
| `Presentation/Art/ChunkArt.swift` | Floor, walls and ground for 16×16-tile map chunks (rasterized once, cached). |
| `Presentation/Art/PropArt.swift` | Furniture and objects (`ObjKind`). |
| `Presentation/Art/FigureArt.swift` | Paper-doll people: head, body, arms, legs, hair, props, outfits; Abe's wheelchair. |
| `Presentation/Art/IconArt.swift` | All 147 icons (`Presentation/Icon.swift` lists them). |
| `Presentation/Art/ChessArt.swift`, `VehicleArt.swift`, `MapArt.swift` | Chess pieces and card suits, carts and vans, the map overview. |
| `Presentation/Art/Pen.swift` | Small drawing helpers (rounded rects, capsules, paths). |

Layout (where things go on screen) is in `Presentation/HUD.swift`, `Menus.swift`,
`EndingScreen.swift`, `WorldPresenter.swift` and each minigame's `build(...)` in
`Sources/FPodCore/Minigames/`.

## How a frame is drawn

1. `Game.buildFrame()` returns a display list: `RenderItem`s (an `ArtKey`, position, z, rotation,
   scale, alpha, layer) plus a few `PolyItem`s (vision cones, noise rings).
2. Each `ArtKey` is turned into a `Drawing` (size, anchor, `[Shape]`) by `ArtLibrary.drawing(_:)`.
   A `Shape` is a `Geom` (rect, ellipse, poly, path, polyline, text) with fill, stroke, line width
   and an optional soft paper shadow.
3. iOS (`iOS/FPod/Rasterizer.swift`) draws each `Drawing` once with CoreGraphics into a texture
   **cached by its `ArtKey`**; `Renderer.swift` places SpriteKit nodes from the display list.
   The dev tool (`Sources/FPodTool/SVGRenderer.swift`) draws the same `Drawing`s as SVG.

## Rules

- **A `Drawing` must be a pure function of its `ArtKey`.** Textures are cached by key, so no
  randomness, time or game state inside art functions. For variation, add a field to the key
  (as `prop(kind, w, h, variant)` does) and seed from it.
- **Anchor = rotation pivot.** A `RenderItem` is placed and rotated about its drawing's anchor.
  UI badges and text use a top-left anchor (0, 0).
- **Only the `Geom` cases above exist.** Gradients, images, blend modes and filters are not
  supported by either renderer; the only effect is the per-shape soft shadow. That matches the
  flat paper-cut look; adding a new geometry needs both `Rasterizer.swift` and `SVGRenderer.swift`.
- **Use `Palette` tokens**, not literal colors. Status colors always go with an icon and a word.
- **Keep sizes stable.** Figures, props and tiles are positioned in tile units (1 tile = 30 pt);
  growing a drawing's size or moving its anchor shifts it in the world and can cover neighbors.
  Touch targets are at least 44 pt.
- **Don't rename ArtKey, Icon or ObjKind cases.** Content refers to them; new art = new case.
- **Text is measured in the core** (`TextMetrics`, an SF Pro Rounded approximation). iOS shrinks
  text that would overflow its box; snapshots emulate that.

## Preview and check

```sh
export PATH=/opt/swift/usr/bin:$PATH      # or any Swift 6 toolchain
swift run fpod-tool scenarios               # list snapshot scenes
tools/snap.sh pod yard fanjobs ending       # → out/*.png (Node + Playwright Chromium)
tools/snap.sh mg-chess@14 mg-kitchenLine@5  # a minigame after its bot plays N seconds
swift run fpod-tool icon                    # app icon PNG from the in-game art
swift test                                  # includes a frame-time budget (dayroom, debug build)
cd tools/ios-typecheck && swift build       # type-checks the iOS layer against SDK stubs
```

Snapshots go through Chromium with DejaVu Sans standing in for SF Pro Rounded, so glyph shapes
differ from the device; spacing is close.

## Boundaries while two people work at once

Gameplay work in progress stays in `Sim/`, `Content/`, `Minigames/` rules and `Tests/`.
Art work owns `Presentation/Art/`, `Util/Color.swift` and `iOS/FPod/Rasterizer.swift`.
Layout files (`HUD.swift`, `Menus.swift`, minigame `build` functions) are shared — keep edits
there small and say which ones you touched.
