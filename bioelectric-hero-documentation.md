# BioElectric Hero Background — Design & Implementation Documentation

## Overview

An animated canvas background representing bio-electric therapy technology. Visualizes intelligent electrical impulses flowing through living tissue, creating a "healing" effect as signals traverse cellular structures.

**Final Output Files:**
- `bioelectric-hero.html` — Full standalone page with hero content
- `bioelectric-embed.html` — Embeddable code block for website builders (Squarespace, etc.)

---

## Visual Concept

### Metaphor
Human tissue as a living Voronoi cellular network. Electrical healing signals originate from a point and radiate outward like neural impulses, activating cells as they pass through. Cells retain a "healing memory" that slowly fades.

### Aesthetic Direction
- **Tone:** Organic, clinical, sophisticated — not sci-fi or gaming
- **Palette:** Deep blue-black base (#020608, #061018, #0a1628) with teal/cyan luminescence (#14b8a6, #38bdf8) and subtle purple accents (#c084fc)
- **Motion:** Slow, breathing, meditative — suitable as a background behind text content

---

## Technical Architecture

### Core Libraries
- **d3-delaunay** (CDN): Computes Voronoi diagram and Delaunay triangulation in real-time

### Key Classes

#### `Point`
Represents a Voronoi seed point / cell center.

```javascript
{
  baseX, baseY,           // Original position
  x, y,                   // Current animated position
  breathPhase,            // Random phase offset for organic motion
  breathSpeed,            // 0.0001 - 0.0003 (very slow)
  breathAmplitudeX/Y,     // 4-14px movement range
  glowPhase,              // Phase for opacity pulsing
  activation              // 0-1 "healing" intensity level
}
```

#### `Pulse`
Invisible signal traveling along Delaunay edges.

```javascript
{
  startIdx, endIdx,       // Point indices
  progress,               // 0-1 travel progress
  speed,                  // 0.035-0.05 per frame
  intensity,              // Energy level (affects cell activation)
  hopCount                // Number of nodes traversed
}
```

---

## Design Decisions & Rationale

### 1. Voronoi + Delaunay Hybrid
- **Voronoi cells**: Organic membrane-like structure (visual)
- **Delaunay edges**: Natural neighbor connections for signal routing (functional)
- Both computed from same point set each frame

### 2. Invisible Signals, Visible Effects
- Early versions showed bright traveling dots — too distracting for background use
- Final: Signals are invisible; only their effect on cells is rendered
- Creates subtle, organic ripple without competing with foreground content

### 3. Energy-Based Signal Propagation
- Signals lose 8% energy per hop (`intensity * 0.92`)
- Energy divides equally among all forward paths at each node
- Death threshold: 6% intensity
- Result: Natural dissipation — signals spread wide but thin out organically

### 4. Directional Continuity
- At each node, signal continues to neighbor with smallest angle deviation from current trajectory
- Prevents backtracking and creates coherent flow patterns
- Only forward-ish directions allowed (<90° deviation)

### 5. Cell Activation & Decay
- **Activation boost**: +70% intensity on signal start, +60% on arrival, +4% while traveling through
- **Exponential decay**: `decayRate = 0.003 + activation * 0.015`
  - Bright cells fade quickly at first
  - Dim cells linger longer (gradual tail)
  - Total duration: ~10 seconds
- **Stacking**: Multiple signals reinforce activation

### 6. Heartbeat Timing
- Bursts spawn every 950ms (~63 BPM resting heart rate)
- Time-based, not frame-based (consistent across devices)
- Multiple bursts can overlap — creates layered, cumulative effect

### 7. Cell Size Response
- Activated cells "swell" up to 30% larger: `sizeBoost = 1 + activation * 0.3`
- Applied to breath amplitude, not base position
- Adds tangible, physical quality to the healing effect

---

## Key Parameters (Tunable)

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `POINT_COUNT` | 250 | Cell density |
| `EDGE_MARGIN` | 50px | Signal death zone at edges |
| `HEARTBEAT_INTERVAL` | 950ms | Burst frequency (~63 BPM) |
| `baseAlpha` | 0.08 ± 0.04 | Cell border opacity (4-12%) |
| `maxAlpha` | 0.33 | Maximum activated opacity (33%) |
| `energyRetention` | 0.92 | Signal strength per hop |
| `deathThreshold` | 0.06 | Minimum signal intensity |
| `activationBoost` | 0.7 / 0.6 | Cell brightness on signal pass |
| `decayRate` | 0.003 + activation * 0.015 | Exponential fade speed |
| `sizeBoost` | 1 + activation * 0.3 | Cell swell on activation |

---

## Visual Layers (Bottom to Top)

1. **Radial gradient background** — Deep blue-black, off-center
2. **Voronoi cell borders** — Teal, 4-33% opacity based on activation
3. **Delaunay edges** — Gradient teal→cyan→purple, distance-faded (currently very subtle)
4. **Noise texture overlay** — 3% opacity SVG noise
5. **Vignette** — Radial fade to edges
6. **Content** — Text, buttons (z-index: 10)

---

## Animation Layers

### Breathing (Always Active)
- All points oscillate slowly around base positions
- Dual-frequency motion for organic feel
- Cell borders pulse 4-12% opacity independently

### Healing Bursts (Heartbeat Triggered)
- Origin point selected randomly (away from edges)
- Pulses spawn on ALL edges from origin
- Signals propagate outward, splitting at nodes
- Cells activate instantly as signals pass
- Activation decays exponentially over ~10 seconds

---

## Embedding Instructions

```html
<!-- Wrapper with desired dimensions -->
<div style="position: relative; width: 100%; height: 100vh;">
  
  <!-- Paste bioelectric-embed.html contents here -->
  
  <!-- Your content on top -->
  <div style="position: relative; z-index: 10;">
    <h1>Your Headline</h1>
  </div>
  
</div>
```

### Squarespace Specific
1. Add Code Block to page
2. Paste entire embed code
3. Animation fills parent container

---

## Future Experimentation Ideas

- **Color theming**: Parameterize the teal/cyan palette for brand customization
- **Interactive bursts**: Trigger on click/touch at cursor position
- **Audio reactivity**: Tie burst timing to music beat detection
- **Density zones**: Vary cell density across canvas (denser near focal point)
- **Signal trails**: Subtle path highlighting showing recent signal routes
- **Multiple origins**: Simultaneous bursts from 2-3 points
- **Configurable heartbeat**: Expose BPM as parameter for different moods

---

## Credits & License

**Author/Designer/Creator:** Anton Goncharov  
**GitHub:** [https://github.com/ag0x00](https://github.com/ag0x00)  
**Built with:** Claude (Anthropic)

### License

MIT License

Copyright (c) 2025 Anton Goncharov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## Performance Notes

- 250 Voronoi points + real-time triangulation = ~60fps on modern devices
- Mobile may benefit from reduced `POINT_COUNT` (150-200)
- Canvas clears and redraws fully each frame (no persistent state)
- d3-delaunay is highly optimized for this use case
