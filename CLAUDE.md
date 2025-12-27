# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Animated canvas background visualizing bio-electric therapy technology. Uses Voronoi/Delaunay diagrams to simulate electrical healing signals flowing through cellular tissue structures.

**Files:**
- `bioelectric-hero.html` - Standalone full-page demo with hero content
- `bioelectric-embed.html` - Embeddable version for website builders (Squarespace, etc.)
- `bioelectric-hero-documentation.md` - Detailed design documentation

## Development

Open HTML files directly in a browser - no build step required. Uses CDN-hosted d3-delaunay library.

## Architecture

### Core Visualization
- **d3-delaunay** computes Voronoi cells (visual membranes) and Delaunay edges (signal pathways) each frame from 250 seed points
- Points "breathe" with dual-frequency oscillation for organic motion
- Canvas redraws fully each frame at ~60fps

### Signal System
1. **Bursts** spawn at heartbeat rate (950ms / ~63 BPM) from random interior points
2. **Pulses** travel invisibly along Delaunay edges, splitting at nodes with directional continuity
3. **Cell activation** increases as pulses pass through (stacking allowed), then decays exponentially (~10s)
4. Visual effect: activated cells glow brighter (up to 33% opacity) and swell (up to 30% larger)

### Energy Model
- Signals retain 92% intensity per hop, divide equally among forward paths
- Death at 6% intensity or edge margin (50px)

### Key Tunable Parameters (in JavaScript)
| Parameter | Default | Purpose |
|-----------|---------|---------|
| `POINT_COUNT` | 250 | Cell density (reduce to 150-200 for mobile) |
| `HEARTBEAT_INTERVAL` | 950ms | Burst frequency |
| `EDGE_MARGIN` | 50px | Signal death zone at edges |
| `energyRetention` | 0.92 | Signal strength per hop |

## Visual Stack (bottom to top)
1. Radial gradient background (deep blue-black)
2. Voronoi cell borders (teal, activation-responsive)
3. Delaunay edges (teal→cyan→purple gradient)
4. SVG noise overlay (3% opacity)
5. Vignette
6. Content layer (z-index: 10)
