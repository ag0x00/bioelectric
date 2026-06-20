# BioElectric Hero Background

An animated canvas background visualizing bio-electric therapy technology. Voronoi cells stand in for living tissue; invisible electrical "healing" signals travel the Delaunay edges between them, activating cells as they pass and leaving a glow that slowly fades.

**Tone:** organic, clinical, meditative — a slow-breathing backdrop for text content, not sci-fi.
**Palette:** deep blue-black base (`#020608`, `#061018`, `#0a1628`) with teal/cyan luminescence (`#14b8a6`, `#38bdf8`) and purple accents (`#c084fc`).

## Files

| File | Purpose |
|------|---------|
| `bioelectric-hero.html` | Standalone full-page demo with hero content |
| `bioelectric-embed.html` | Embeddable version for website builders (Squarespace, etc.) |
| `bioelectric-core.js` | Shared animation engine |
| `bioelectric-core.css` | Shared styles |

Open either HTML file directly in a browser — no build step. `d3-delaunay` loads from CDN.

## How it works

`d3-delaunay` recomputes the Voronoi cells (visual membranes) and Delaunay edges (signal pathways) every frame from ~250 seed points. Points "breathe" with dual-frequency oscillation for organic motion.

1. **Bursts** spawn at heartbeat rate (~63 BPM) from a random interior point, emitting pulses on all its edges.
2. **Pulses** travel invisibly along Delaunay edges, splitting at nodes and continuing in forward-ish directions only (<90° deviation from current trajectory) to avoid backtracking.
3. **Cell activation** rises as pulses pass through (stacking allowed), then decays exponentially over ~10s.
4. Activated cells glow brighter (up to 33% opacity) and swell (up to 30% larger).

**Energy model:** signals retain 92% intensity per hop and divide equally among forward paths, dying at 6% intensity or within the 50px edge margin. The result is natural dissipation — signals spread wide but thin out organically.

### Why signals are invisible
Early versions drew bright traveling dots — too distracting behind text. Rendering only the *effect* on cells gives a subtle organic ripple that doesn't compete with foreground content.

## Tunable parameters

In `bioelectric-core.js`:

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `POINT_COUNT_DESKTOP` / `_MOBILE` | 250 / 175 | Cell density |
| `HEARTBEAT_INTERVAL` | 950ms | Burst frequency (~63 BPM) |
| `EDGE_MARGIN` | 50px | Signal death zone at edges |
| `ENERGY_RETENTION` | 0.92 | Signal strength per hop |
| `DEATH_THRESHOLD` | 0.06 | Minimum signal intensity |
| `MAX_ALPHA` | 0.33 | Maximum activated cell opacity |
| `ACTIVATION_BOOST_START` / `_END` | 0.7 / 0.6 | Cell brightness on signal pass |

## Visual stack (bottom to top)

1. Radial gradient background (deep blue-black, off-center)
2. Voronoi cell borders (teal, 4–33% opacity by activation)
3. Delaunay edges (teal→cyan→purple gradient, distance-faded)
4. SVG noise overlay (3% opacity)
5. Vignette
6. Content layer (`z-index: 10`)

## Embedding

```html
<div style="position: relative; width: 100%; height: 100vh;">
  <!-- paste bioelectric-embed.html contents here -->
  <div style="position: relative; z-index: 10;">
    <h1>Your Headline</h1>
  </div>
</div>
```

In Squarespace: add a Code Block, paste the embed code, and the animation fills its parent container.

## Performance

~60fps on modern devices with 250 points and real-time triangulation. The canvas redraws fully each frame (no persistent state). Reduce `POINT_COUNT_*` for low-end mobile.

## Credits & license

Created by Anton Goncharov ([@ag0x00](https://github.com/ag0x00)), built with Claude (Anthropic). MIT License, Copyright (c) 2025 Anton Goncharov.
