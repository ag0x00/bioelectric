# BioElectric Screensaver

Native screensavers of the BioElectric animation for macOS and Windows.

```
macos/           .saver bundle — native Swift + CoreGraphics (no WebView)
windows/         .scr source — C# + WebView2 (wraps the offline web page)
web_content/     self-contained offline web page (used by Windows only)
wallpaper-design.md   planned macOS live-wallpaper + Metal renderer (design only)
```

The two platforms render differently on purpose — see [macOS](#macos) below.

## macOS — native Swift

macOS renders the animation **natively** with CoreGraphics; it does not use a
WebView. We tried wrapping `web_content` in a `WKWebView` first, but on macOS 14+
the `legacyScreenSaver` engine suspends the web process as "not visible" and it
never paints (black screen). The native port avoids WebKit entirely.

```bash
cd macos && ./build_mac.sh
cp -R BioElectric.saver ~/Library/"Screen Savers"/
```

Then open **System Settings → Screen Saver** and pick BioElectric. Builds a
signed universal binary (arm64 + x86_64) with `swiftc` — no Xcode project, just
Command Line Tools.

Sources:
- `Geometry.swift` — Delaunay triangulation (Bowyer-Watson)
- `BioElectricView.swift` — `ScreenSaverView` subclass: points, pulses, rendering
- `Info.plist`, `build_mac.sh`
- `thumbnail.png` / `thumbnail@2x.png`, `generate_thumbnail.js` — picker thumbnail

**Picker thumbnail.** System Settings shows `thumbnail.png` / `thumbnail@2x.png`
(in `Contents/Resources/`) in the screen-saver grid; without them macOS falls back
to a generic icon. `generate_thumbnail.js` renders them from the same
`d3-delaunay` the web engine uses — run `node generate_thumbnail.js` and rebuild.
The dark live preview at the top of the pane renders the saver itself, not these.
(Note: the legacy-`.saver` picker thumbnail has been buggy on some recent macOS
releases — if the grid still shows the generic icon, re-select the saver or
log out and back in.)

**Planned — live wallpaper.** macOS Tahoe can keep a screen saver running as the
animated desktop *background* after login. There's no public API to do that from a
`.saver`, so the plan is a companion agent app that shares a Metal port of the
renderer. Full design and phased plan in
[`wallpaper-design.md`](wallpaper-design.md) — nothing built yet.

## Windows — WebView2

Windows wraps the `web_content` page in a WebView2 control (no suspension issue
there). Build on a Windows machine (or VM) with the .NET 8 SDK:

```
cd windows
dotnet publish -c Release -r win-x64 --self-contained false
```

Rename the output `BioElectric.exe` → `BioElectric.scr`, then right-click → Install
(or drop it in `C:\Windows\System32`). Requires the WebView2 runtime (preinstalled
on Windows 11). Handles `/s` (full screen), `/p <hwnd>` (preview), `/c` (no settings).

`web_content/` is the offline page: `index.html` + vendored `d3-delaunay.js`. The
shared `bioelectric-core.js` / `bioelectric-core.css` live at the repo root and are
copied in by the Windows build — never duplicated in git. No CDN; runs offline.

## Updating the animation

The animation logic lives in **two** places now and must be kept in sync by hand:
- **macOS:** `macos/BioElectricView.swift` (and `Geometry.swift`)
- **Windows / web:** the root `bioelectric-core.js`

Tunable constants (point count, heartbeat interval, energy model) sit at the top
of each. After editing, rerun the platform's build.

## Not included (deferred)

Code signing / notarization, `.pkg` / Inno-Setup installers, multi-monitor
spanning, and a battery-saver frame cap. The macOS `.saver` is ad-hoc signed so it
loads locally, but Gatekeeper will still warn on other machines until it's
notarized with an Apple Developer ID.
