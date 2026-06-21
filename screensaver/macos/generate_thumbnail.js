// Generates thumbnail.png (480x300) + thumbnail@2x.png (960x600) for the
// macOS screen-saver picker. Renders a representative still of the BioElectric
// animation — a heartbeat lighting a cluster of cells — brighter and
// higher-contrast than the ambient animation so it reads at icon size.
//
// Uses the same vendored d3-delaunay as the web engine; no other dependencies.
// Run:  node generate_thumbnail.js   (writes the two PNGs next to this file)
const fs = require("fs");
const zlib = require("zlib");
const path = require("path");
const { Delaunay } = require(path.join(
  __dirname, "..", "web_content", "vendor", "d3-delaunay.js"
));

// --- render config (in @2x pixels) ------------------------------------------
const W = 960, H = 600;          // @2x master; @1x is a 2x2 box downsample
const POINT_COUNT = 230;
const SEED = 7;

// palette (matches README / bioelectric-core.js)
const TEAL = [20, 184, 166];
const CYAN = [56, 189, 248];
const PURPLE = [192, 132, 252];
const WHITE = [236, 248, 255];

const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
const mix = (u, v, t) => [
  u[0] + (v[0] - u[0]) * t,
  u[1] + (v[1] - u[1]) * t,
  u[2] + (v[2] - u[2]) * t,
];
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rng = mulberry32(SEED);

// --- buffer (opaque RGB, float 0..1) ----------------------------------------
const buf = new Float32Array(W * H * 3);
function over(x, y, c, a) {
  if (a <= 0 || x < 0 || y < 0 || x >= W || y >= H) return;
  const i = (y * W + x) * 3, ia = 1 - a;
  buf[i] = buf[i] * ia + (c[0] / 255) * a;
  buf[i + 1] = buf[i + 1] * ia + (c[1] / 255) * a;
  buf[i + 2] = buf[i + 2] * ia + (c[2] / 255) * a;
}
function add(x, y, c, k) {
  if (k <= 0 || x < 0 || y < 0 || x >= W || y >= H) return;
  const i = (y * W + x) * 3;
  buf[i] = clamp(buf[i] + (c[0] / 255) * k, 0, 1);
  buf[i + 1] = clamp(buf[i + 1] + (c[1] / 255) * k, 0, 1);
  buf[i + 2] = clamp(buf[i + 2] + (c[2] / 255) * k, 0, 1);
}

// --- background: off-center radial gradient ---------------------------------
(function background() {
  const cx = W * 0.3, cy = H * 0.4, rmax = W * 0.9;
  const s0 = [10, 22, 40], s1 = [6, 16, 24], s2 = [2, 6, 8]; // #0a1628 #061018 #020608
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const t = clamp(Math.hypot(x - cx, y - cy) / rmax, 0, 1);
      const c = t < 0.5 ? mix(s0, s1, t * 2) : mix(s1, s2, (t - 0.5) * 2);
      const i = (y * W + x) * 3;
      buf[i] = c[0] / 255; buf[i + 1] = c[1] / 255; buf[i + 2] = c[2] / 255;
    }
  }
})();

// --- geometry: same grid+jitter seeding as the engine -----------------------
const cols = Math.ceil(Math.sqrt(POINT_COUNT * (W / H)));
const rows = Math.ceil(POINT_COUNT / cols);
const cellW = W / cols, cellH = H / rows;
const pts = [];
for (let k = 0; k < POINT_COUNT; k++) {
  const col = k % cols, row = Math.floor(k / cols);
  const x = clamp((col + 0.5) * cellW + (rng() - 0.5) * cellW * 0.9, 0, W);
  const y = clamp((row + 0.5) * cellH + (rng() - 0.5) * cellH * 0.9, 0, H);
  pts.push([x, y]);
}
const delaunay = Delaunay.from(pts);
const voronoi = delaunay.voronoi([0, 0, W, H]);

// --- activation: a burst lighting a cluster near the visual center ----------
const act = new Float32Array(pts.length);
let origin = 0, best = Infinity;
for (let i = 0; i < pts.length; i++) {
  const d = Math.hypot(pts[i][0] - W * 0.44, pts[i][1] - H * 0.46);
  if (d < best) { best = d; origin = i; }
}
act[origin] = 1;
for (const n of delaunay.neighbors(origin)) {
  act[n] = Math.max(act[n], 0.72);
  for (const m of delaunay.neighbors(n)) act[m] = Math.max(act[m], 0.34);
}

// --- anti-aliased line (per-pixel distance over the segment bbox) -----------
function line(ax, ay, bx, by, color, alpha, radius) {
  if (alpha <= 0.004) return;
  const minx = Math.max(0, Math.floor(Math.min(ax, bx) - radius - 1));
  const maxx = Math.min(W - 1, Math.ceil(Math.max(ax, bx) + radius + 1));
  const miny = Math.max(0, Math.floor(Math.min(ay, by) - radius - 1));
  const maxy = Math.min(H - 1, Math.ceil(Math.max(ay, by) + radius + 1));
  const dx = bx - ax, dy = by - ay, len2 = dx * dx + dy * dy || 1e-6;
  for (let y = miny; y <= maxy; y++) {
    for (let x = minx; x <= maxx; x++) {
      let t = ((x - ax) * dx + (y - ay) * dy) / len2;
      t = clamp(t, 0, 1);
      const px = ax + t * dx, py = ay + t * dy;
      const d = Math.hypot(x - px, y - py);
      const cov = clamp(radius + 0.6 - d, 0, 1); // ~1px AA falloff
      if (cov > 0) over(x, y, color, alpha * cov);
    }
  }
}

// --- Delaunay edges: distance-faded teal->cyan->purple gradient -------------
const maxDist = Math.max(W, H) * 0.15;
const tris = delaunay.triangles;
const seen = new Set();
for (let t = 0; t < tris.length; t += 3) {
  for (let e = 0; e < 3; e++) {
    const a = tris[t + e], b = tris[t + ((e + 1) % 3)];
    const key = a < b ? a * pts.length + b : b * pts.length + a;
    if (seen.has(key)) continue;
    seen.add(key);
    const [ax, ay] = pts[a], [bx, by] = pts[b];
    const len = Math.hypot(ax - bx, ay - by);
    const fade = Math.max(0, 1 - len / maxDist);
    const alpha = fade * 0.15;
    if (alpha < 0.01) continue;
    // sample two sub-segments so the 3-stop gradient shows along the edge
    const mx = (ax + bx) / 2, my = (ay + by) / 2;
    line(ax, ay, mx, my, mix(TEAL, CYAN, 0.5), alpha, 0.8);
    line(mx, my, bx, by, mix(CYAN, PURPLE, 0.5), alpha, 0.8);
  }
}

// --- Voronoi cell borders: teal, brighter+thicker where activated -----------
for (let i = 0; i < pts.length; i++) {
  const poly = voronoi.cellPolygon(i);
  if (!poly) continue;
  const a = act[i];
  let color = mix(TEAL, CYAN, clamp(a, 0, 1));
  if (a > 0.6) color = mix(color, WHITE, (a - 0.6) / 0.4);
  const jitter = (rng() - 0.5) * 0.05;
  const alpha = clamp(0.17 + jitter + a * 0.6, 0, 0.92);
  const radius = 1.0 + a * 1.9;
  for (let k = 0; k < poly.length - 1; k++) {
    line(poly[k][0], poly[k][1], poly[k + 1][0], poly[k + 1][1], color, alpha, radius);
  }
}

// --- glow on the activated cluster ------------------------------------------
for (let i = 0; i < pts.length; i++) {
  if (act[i] < 0.35) continue;
  const [cx, cy] = pts[i], r = 55 + act[i] * 75, k0 = act[i] * 0.4;
  const minx = Math.max(0, Math.floor(cx - r)), maxx = Math.min(W - 1, Math.ceil(cx + r));
  const miny = Math.max(0, Math.floor(cy - r)), maxy = Math.min(H - 1, Math.ceil(cy + r));
  for (let y = miny; y <= maxy; y++) {
    for (let x = minx; x <= maxx; x++) {
      const f = 1 - Math.hypot(x - cx, y - cy) / r;
      if (f > 0) add(x, y, CYAN, k0 * f * f);
    }
  }
}

// --- vignette ---------------------------------------------------------------
(function vignette() {
  const cx = W * 0.5, cy = H * 0.5, rmax = Math.max(W, H) * 0.7;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const a = 0.5 * clamp(Math.hypot(x - cx, y - cy) / rmax, 0, 1);
      over(x, y, [2, 6, 8], a);
    }
  }
})();

// --- PNG encode (8-bit RGB, color type 2) -----------------------------------
const CRC = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(b) {
  let c = 0xffffffff;
  for (let i = 0; i < b.length; i++) c = CRC[(c ^ b[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const t = Buffer.from(type, "ascii");
  const body = Buffer.concat([t, data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([len, body, crc]);
}
function encodePNG(w, h, rgb /* Uint8 length w*h*3 */) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const stride = w * 3;
  const raw = Buffer.alloc((stride + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (stride + 1)] = 0; // filter: none
    rgb.copy ? rgb.copy(raw, y * (stride + 1) + 1, y * stride, y * stride + stride)
             : raw.set(rgb.subarray(y * stride, y * stride + stride), y * (stride + 1) + 1);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr), chunk("IDAT", idat), chunk("IEND", Buffer.alloc(0)),
  ]);
}
function toBytes(fbuf, w, h) {
  const out = Buffer.alloc(w * h * 3);
  for (let i = 0; i < w * h * 3; i++) out[i] = Math.round(clamp(fbuf[i], 0, 1) * 255);
  return out;
}
// @1x via 2x2 box downsample of the float master
function downsample2x() {
  const w = W >> 1, h = H >> 1;
  const out = new Float32Array(w * h * 3);
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++)
      for (let c = 0; c < 3; c++) {
        const sx = x * 2, sy = y * 2;
        out[(y * w + x) * 3 + c] = 0.25 * (
          buf[((sy) * W + sx) * 3 + c] + buf[((sy) * W + sx + 1) * 3 + c] +
          buf[((sy + 1) * W + sx) * 3 + c] + buf[((sy + 1) * W + sx + 1) * 3 + c]);
      }
  return { w, h, out };
}

fs.writeFileSync(path.join(__dirname, "thumbnail@2x.png"),
  encodePNG(W, H, toBytes(buf, W, H)));
const d = downsample2x();
fs.writeFileSync(path.join(__dirname, "thumbnail.png"),
  encodePNG(d.w, d.h, toBytes(d.out, d.w, d.h)));
console.log(`wrote thumbnail.png (${d.w}x${d.h}) and thumbnail@2x.png (${W}x${H})`);
