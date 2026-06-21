# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project Overview

Animated canvas background visualizing bio-electric therapy technology. Uses Voronoi/Delaunay diagrams to simulate electrical healing signals flowing through cellular tissue.

See **`README.md`** for the architecture, signal/energy model, visual stack, and the full table of tunable parameters — it's the single source of truth. Don't restate those details here; update the README instead. The native screen-saver ports have their own source of truth in **`screensaver/README.md`**.

## Development

Open the HTML files directly in a browser — no build step. `d3-delaunay` loads from CDN.

- `bioelectric-hero.html` — standalone full-page demo
- `bioelectric-embed.html` — embeddable version for website builders
- `bioelectric-core.js` / `bioelectric-core.css` — shared engine and styles
- `screensaver/` — native macOS/Windows screen-saver ports (see `screensaver/README.md`); `screensaver/wallpaper-design.md` is the design for the planned macOS live wallpaper

Tunable parameters are the `const`s at the top of `bioelectric-core.js`. The animation auto-starts when `createBioElectricAnimation(canvas, opts)` is called.
