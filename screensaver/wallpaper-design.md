# macOS Live Wallpaper + Metal Renderer — Design

Goal: make BioElectric behave like a macOS Tahoe **Dynamic Wallpaper** — it plays
as the screen saver while idle, and **keeps animating as the desktop background
after login** — and move the native renderer from CoreGraphics to **Metal** so it
is cheap enough to run continuously.

This is a forward-looking design doc — nothing here is built yet. The current
shipped state is described in `README.md`; update that once this lands, not before.

## 1. The honest constraint

There is **no public API for a third-party `.saver` to register as a Dynamic
Wallpaper.** Tahoe's "screen saver that becomes the wallpaper" is wired only to
Apple's bundled video assets under
`/Library/Application Support/com.apple.idleassetsd/Customer/`. We cannot plug a
`ScreenSaverView` into that slot, and we will not pre-render to video (loses the
live signal/energy model; see the chat that spawned this doc).

So we reproduce the *experience* with **two cooperating pieces that share one
engine**:

| Piece | Role | Host |
| --- | --- | --- |
| `BioElectric.saver` (exists) | Plays while idle / on lock screen | `legacyScreenSaver` engine |
| `BioElectricWallpaper.app` (new) | Animated desktop background, persists after login | `LSUIElement` agent app |

Both render the **same simulation** through the **same Metal renderer**. The
wallpaper app is what delivers the "continues after login" half; the saver keeps
the idle slot it already owns.

## 2. Architecture — split sim from render

Today `BioElectricView.swift` mixes three concerns: the model (`Point`, `Pulse`,
`spawnBurst`, `animateOneFrame` at `:157`), the CoreGraphics drawing
(`draw`/`drawCells`/`drawEdges` at `:177–264`), and the AppKit host
(`ScreenSaverView`). To feed three hosts (saver, wallpaper, and any future
preview) from one engine, we split into a **platform-agnostic sim** and a
**Metal renderer**, each host being a thin shell.

```
screensaver/macos/
  Geometry.swift            # unchanged — Bowyer-Watson neighbors
  BioElectricSim.swift      # NEW  pure model: points, pulses, neighbors, step(dt)
  BioElectricRenderer.swift # NEW  Metal: sim state -> vertex buffers -> draw
  Shaders.metal             # NEW  vertex + fragment shaders, gradients, glow
  RenderHost.swift          # NEW  shared CAMetalLayer setup + frame driver

  BioElectricView.swift     # SLIMMED  ScreenSaverView shell -> Sim + Renderer
  Info.plist                # saver plist (unchanged)
  build_mac.sh              # +metal compile, builds both targets

  wallpaper/                # NEW app target
    main.swift              # LSUIElement bootstrap, login-item registration
    DesktopWindowController.swift  # one desktop-level window per NSScreen
    Info.plist              # LSUIElement=YES, login-item friendly
```

`Geometry.swift` is already pure and is reused as-is. Nothing here duplicates
the model — the README's "two places" pain (Swift vs `bioelectric-core.js`) does
**not** get a third entry; on the native side this *collapses* the saver and
wallpaper onto one sim + one renderer.

## 3. The sim module (`BioElectricSim.swift`)

Lift `Point`, `Pulse`, `initPoints`, `spawnBurst`, and the body of
`animateOneFrame` out of the view verbatim — they already have no drawing or
AppKit dependencies beyond `CGPoint`/`CGSize`. Expose a host-agnostic surface:

```swift
final class BioElectricSim {
    private(set) var points: [Point] = []
    private(set) var neighbors: [[Int]] = []
    private(set) var pulses: [Pulse] = []
    private(set) var time = 0.0

    var size: CGSize { didSet { if size != oldValue { initPoints() } } }

    /// Advance the model. dt in milliseconds (the view currently uses
    /// animationTimeInterval * 1000 at BioElectricView.swift:161).
    func step(dt: Double) { /* time += dt; update points; re-triangulate;
                               heartbeat burst; advance pulses */ }
}
```

No behavior change — this is a pure extraction. Verify the saver still looks
identical *before* touching the renderer.

> Note: `step` still calls `Delaunay.neighbors(...)` every frame
> (`BioElectricView.swift:163`). Metal does **not** speed that up — it is the
> CPU cost that dominates at 250 points. Caching/incrementally updating the
> triangulation and capping the frame rate (§8) are the real continuous-run
> levers and are independent of Metal. Keep `step` as the seam where that
> optimization later lands.

## 4. The Metal renderer (`BioElectricRenderer.swift` + `Shaders.metal`)

### Surface
- A `CAMetalLayer` (set up in `RenderHost.swift`), `pixelFormat
  .bgra8Unorm`, `framebufferOnly = true`, `drawableSize = bounds.size *
  contentsScale`. Set the layer `colorspace` to sRGB so colors match the current
  CoreGraphics `deviceRGB` output (otherwise teal/cyan shift).
- One command queue; one `MTLRenderPipelineState` per primitive class (gradient
  quads, lines). Alpha blending on: `sourceAlpha` / `oneMinusSourceAlpha`,
  matching today's painter's-algorithm look. (Additive blending is an option for
  the glow pass — see below.)

### Per-frame geometry (CPU → vertex buffer)
The renderer reads `sim.points` / `sim.neighbors` and builds vertex arrays each
frame. Counts are small (~250 cells, a few hundred edges), so rebuilding a
`MTLBuffer` per frame is fine; double-buffer to avoid CPU/GPU stalls.

1. **Background** — one full-screen quad; radial gradient in the fragment shader
   (port `drawBackground` `:186`, three stops `#0a1628 → #061018 → #020608`).
2. **Voronoi cells** — same half-plane clip as `drawCells` (`:201`, reusing the
   `clip` helper at `:231`) to get each cell polygon, then emit its outline.
   Metal has **no thick-line primitive**, so expand each segment to a
   triangle-strip quad of width `1 + activation*0.8`. Per-vertex RGBA carries the
   teal `rgba(20,184,166, alpha)` with the activation-driven alpha from `:217–219`.
3. **Edges** — port `drawEdges` (`:246`) with the same distance falloff
   (`alpha = max(0,1-dist/maxDist)*0.12`). Expand to quads, and this time give the
   two endpoints **different colors** so the fragment shader interpolates the
   web's 3-stop teal→cyan→purple gradient (`bioelectric-core.js:331–334`) that the
   CoreGraphics port had to flatten to a single cyan line (`:247`). Metal gets the
   web fidelity back for free.
4. **Vignette** — full-screen quad, radial alpha 0→0.5 (port `drawVignette` `:266`).

### Shaders
A passthrough vertex shader (clip-space transform of pixel coords; remember
`isFlipped`/y-down, `:125`) and two fragment shaders: a `radialGradient` for
bg/vignette and a `lineColor` that just emits the interpolated vertex color.

### Glow (fidelity upgrade, do last)
Two options, cheapest first:
- **Soft lines:** widen the line quads slightly and fall off alpha by
  perpendicular distance in the fragment shader. Nearly free, gives a believable
  neon edge.
- **Bloom pass:** render bright primitives to an offscreen texture, downsample +
  separable Gaussian blur, additively composite. More faithful to "electric
  glow," heavier. Defer to a later phase.

## 5. The wallpaper host (`wallpaper/`)

A background agent app, no Dock icon, one borderless window per display sitting
behind the icons.

### Window per screen (`DesktopWindowController.swift`)
```swift
let win = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                   backing: .buffered, defer: false, screen: screen)
win.level = NSWindow.Level(rawValue:
    Int(CGWindowLevelForKey(.desktopWindow)))   // ⚠ verify exact level on Tahoe
win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
win.ignoresMouseEvents = true     // clicks fall through to Finder/desktop
win.isOpaque = true               // we paint a full dark bg; no transparency cost
win.hasShadow = false
win.canHide = false
win.contentView = RenderHostView(sim: sharedSim, renderer: sharedRenderer)
win.orderBack(nil)
```
- **Level:** we want *above the static wallpaper, below the desktop icons.*
  `kCGDesktopWindowLevel` is the usual choice; on some configs the icons sit on a
  separate `kCGDesktopIconWindowLevel`, so `.desktopIconWindow - 1` is the
  fallback. **Validate on Tahoe** — this is the #1 thing to confirm in the spike.
- **Spaces:** `.canJoinAllSpaces` + `.stationary` makes one window cover every
  Space without animating on switch.
- **Multi-monitor:** create one controller per `NSScreen`; observe
  `NSApplication.didChangeScreenParametersNotification` and rebuild on
  resolution/arrangement/display hot-plug changes.

### Persist after login (the "Tahoe" half)
Register the app as a login item with ServiceManagement (macOS 13+):
```swift
try? SMAppService.mainApp.register()   // user approves in Settings > Login Items
```
First run should explain the one-time approval. This is what makes the wallpaper
"continue after login" without the user relaunching anything.

### `Info.plist`
`LSUIElement = YES` (agent, no Dock/menu bar), `NSPrincipalClass`
`NSApplication`, `LSMinimumSystemVersion` 14.0 (Metal-on-desktop + CADisplayLink;
Tahoe is the target but keep a sane floor), universal binary like the saver.

## 6. The saver host (`BioElectricView.swift`, slimmed)

`ScreenSaverView` keeps owning the engine via `animateOneFrame` but delegates:
`sim.step(dt: animationTimeInterval*1000)` then `renderer.render(sim, into:
metalLayer)`. Drawing code (`draw`/`drawCells`/`drawEdges`/`drawVignette`) is
deleted — it now lives in the renderer. The view backs itself with a
`CAMetalLayer` (via `RenderHost`) instead of drawing into the CG context.

⚠ **Risk:** the saver runs inside the sandboxed `legacyScreenSaver.appex`, where
`CAMetalLayer` has historically been finicky. The spike (§10, Phase 0) decides
this. If Metal won't paint in the saver sandbox, the low-risk fork is: **saver
stays on CoreGraphics, Metal ships in the wallpaper app only.** The sim split
(§3) makes either outcome cheap.

## 7. Build changes (`build_mac.sh`)

Add ahead of the Swift compile:
```bash
xcrun -sdk macosx metal   -c "$HERE/Shaders.metal" -o "$BUILD/Shaders.air"
xcrun -sdk macosx metallib   "$BUILD/Shaders.air"  -o "$BUILD/default.metallib"
```
- Add `BioElectricSim.swift`, `BioElectricRenderer.swift`, `RenderHost.swift` to
  the saver `SOURCES`; link `-framework Metal -framework QuartzCore`.
- Copy `default.metallib` into `BioElectric.saver/Contents/Resources/`. Load it
  with `device.makeDefaultLibrary(bundle: Bundle(for: BioElectricView.self))`.
- New second target: compile `wallpaper/*.swift` + shared sources into
  `BioElectricWallpaper.app/Contents/MacOS/`, with its own `Info.plist` and a
  copy of `default.metallib` in its `Resources/`; link `-framework AppKit
  -framework Metal -framework ServiceManagement`. Ad-hoc sign both, same as the
  saver does today (`build_mac.sh:35`).
- Keep the universal (arm64 + x86_64) lipo flow for both.

## 8. Energy (matters now — runs 24/7)

The saver only ran while idle; the wallpaper runs during real work, so:
- **Cap frame rate.** Drive the wallpaper with `CADisplayLink`
  (`preferredFrameRateRange` ≈ 24–30fps). The saver keeps its 60fps engine
  timing or is likewise lowered.
- **Pause when covered.** Watch `NSWindow.occlusionState` /
  `didChangeOcclusionStateNotification` and stop the display link when a
  fullscreen app fully hides the desktop. Stop on display sleep.
- **Throttle the sim, not just the draw.** Per §3, the per-frame
  re-triangulation is the CPU hog; lowering frame rate cuts it proportionally,
  and caching neighbors across frames is the bigger win when we get to it.

## 9. Tricky bits / risks

1. **`CAMetalLayer` in the saver sandbox** — validate first (§6). Drives whether
   the saver moves to Metal at all.
2. **Desktop window level on Tahoe** — exact constant to sit above wallpaper /
   below icons (§5). Validate in the spike.
3. **`.metallib` loading per bundle** — saver vs app have different bundles; use
   the right `Bundle(for:)`/`Bundle.main`. A missing lib = black screen.
4. **Color management** — set the Metal layer colorspace to sRGB so output
   matches the CG `deviceRGB` palette; otherwise the teals shift.
5. **Thick-line quads** — joins between cell-outline segments can show gaps;
   round caps or small miters. Skip degenerate (<3-vertex) clipped cells as the
   CG code already does (`:214`).
6. **Login-item approval** — `SMAppService` needs user consent; handle the
   not-yet-approved state gracefully and tell the user where to enable it.
7. **Display hot-plug / Spaces** — rebuild windows on screen-param changes; test
   docking/undocking and multiple displays.
8. **Notarization / distribution** — still out of scope (carries over from
   README "Not included"); ad-hoc signing loads locally only.

## 10. Phased plan (each phase independently testable)

- **Phase 0 — Spike (de-risk).** Minimal `CAMetalLayer` that clears to a color,
  hosted (a) in a `.saver` and (b) in a desktop-level window on Tahoe. Confirms
  the two unknowns: Metal paints in the saver sandbox, and the window level sits
  correctly behind icons. Outcome decides §6's fork.
- **Phase 1 — Extract sim.** Move model code into `BioElectricSim.swift`; saver
  still CoreGraphics. Pure refactor; verify identical output.
- **Phase 2 — Metal renderer.** `BioElectricRenderer` + `Shaders.metal`; swap the
  host(s) chosen in Phase 0 onto it. Parity check vs CoreGraphics, then restore
  the edge gradient (§4.3).
- **Phase 3 — Wallpaper app.** Desktop windows, multi-monitor, `LSUIElement`,
  login-item registration. This is the deliverable the user asked for.
- **Phase 4 — Energy.** Frame-rate cap, occlusion/sleep pause; optional neighbor
  caching.
- **Phase 5 — Glow + packaging.** Bloom pass; revisit signing/notarization/
  installer (still deferred per README).

## 11. Deferred

Code signing / notarization, a `.pkg`/installer for the wallpaper app, the bloom
pass, neighbor-cache optimization, and any settings UI. Same posture as the
README's existing "Not included" section.
