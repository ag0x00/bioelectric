import ScreenSaver
import CoreGraphics

// Native port of bioelectric-core.js — Voronoi "tissue" with electrical pulses,
// rendered with CoreGraphics so it runs reliably in the macOS screensaver engine
// (WKWebView gets suspended as "not visible" and never paints).

private let ENERGY_RETENTION = 0.92
private let DEATH_THRESHOLD = 0.06
private let ACTIVATION_BOOST_START = 0.7
private let ACTIVATION_BOOST_END = 0.6
private let MAX_ALPHA = 0.33
private let EDGE_MARGIN = 50.0
private let HEARTBEAT_INTERVAL = 950.0 // ms, ~63 BPM
private let MOBILE_BREAKPOINT = 768.0
private let POINT_COUNT_DESKTOP = 250
private let POINT_COUNT_MOBILE = 175

private struct Point {
    let baseX, baseY: Double
    var x, y: Double
    let breathPhase, breathSpeed, breathAmplitudeX, breathAmplitudeY: Double
    let breathPhase2, breathSpeed2, glowPhase: Double
    var activation = 0.0

    init(x: Double, y: Double) {
        baseX = x; baseY = y; self.x = x; self.y = y
        breathPhase = Double.random(in: 0..<(2 * .pi))
        breathSpeed = 0.0001 + Double.random(in: 0..<0.0002)
        breathAmplitudeX = 4 + Double.random(in: 0..<10)
        breathAmplitudeY = 4 + Double.random(in: 0..<10)
        breathPhase2 = Double.random(in: 0..<(2 * .pi))
        breathSpeed2 = 0.00005 + Double.random(in: 0..<0.0001)
        glowPhase = Double.random(in: 0..<(2 * .pi))
    }

    mutating func update(_ time: Double) {
        let breath1 = sin(time * breathSpeed + breathPhase)
        let breath2 = sin(time * breathSpeed2 + breathPhase2) * 0.5
        let sizeBoost = 1 + activation * 0.3
        x = baseX + (breath1 + breath2) * breathAmplitudeX * sizeBoost
        y = baseY + cos(time * breathSpeed * 0.8 + breathPhase) * breathAmplitudeY * sizeBoost
                  + cos(time * breathSpeed2 + breathPhase2) * breathAmplitudeY * 0.3 * sizeBoost
        let decayRate = 0.003 + activation * 0.015
        activation -= activation * decayRate
        if activation < 0.005 { activation = 0 }
    }
}

private final class Pulse {
    var startIdx, endIdx: Int
    var progress = 0.0
    let speed = 0.035 + Double.random(in: 0..<0.015)
    var alive = true
    var intensity: Double
    var hopCount: Int
    var activatedStart = false

    init(_ startIdx: Int, _ endIdx: Int, hopCount: Int = 0, intensity: Double = 1) {
        self.startIdx = startIdx; self.endIdx = endIdx
        self.hopCount = hopCount; self.intensity = intensity
    }

    private func nearEdge(_ p: Point, _ w: Double, _ h: Double) -> Bool {
        p.x < EDGE_MARGIN || p.x > w - EDGE_MARGIN || p.y < EDGE_MARGIN || p.y > h - EDGE_MARGIN
    }

    func update(neighbors: [[Int]], points: inout [Point], spawn: inout [Pulse], w: Double, h: Double) {
        if !activatedStart {
            points[startIdx].activation = min(1, points[startIdx].activation + intensity * ACTIVATION_BOOST_START)
            activatedStart = true
        }
        if progress > 0.3 && progress < 0.7 {
            points[endIdx].activation = min(1, points[endIdx].activation + intensity * 0.04)
        }
        progress += speed
        guard progress >= 1 else { return }

        points[endIdx].activation = min(1, points[endIdx].activation + intensity * ACTIVATION_BOOST_END)
        if nearEdge(points[endIdx], w, h) { alive = false; return }
        hopCount += 1

        let s = points[startIdx], e = points[endIdx]
        let travelAngle = atan2(e.y - s.y, e.x - s.x)
        let valid = neighbors[endIdx].filter { $0 != startIdx }
        if valid.isEmpty { alive = false; return }

        var withAngles = valid.map { n -> (idx: Int, dev: Double) in
            var dev = abs(atan2(points[n].y - e.y, points[n].x - e.x) - travelAngle)
            if dev > .pi { dev = 2 * .pi - dev }
            return (n, dev)
        }
        withAngles.sort { $0.dev < $1.dev }
        let forward = withAngles.filter { $0.dev < .pi / 2 }
        if forward.isEmpty { alive = false; return }

        let energyPerPath = (intensity * ENERGY_RETENTION) / Double(forward.count)
        if energyPerPath < DEATH_THRESHOLD { alive = false; return }

        for i in 1..<forward.count {
            spawn.append(Pulse(endIdx, forward[i].idx, hopCount: hopCount, intensity: energyPerPath))
        }
        startIdx = endIdx
        endIdx = forward[0].idx
        progress = 0
        intensity = energyPerPath
    }
}

final class BioElectricView: ScreenSaverView {
    private var points: [Point] = []
    private var neighbors: [[Int]] = []
    private var pulses: [Pulse] = []
    private var time = 0.0
    private var lastBurst = 0.0
    private var sized = CGSize.zero

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 60.0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }       // match the web canvas (y-down)

    private var w: Double { Double(bounds.width) }
    private var h: Double { Double(bounds.height) }

    private func initPoints() {
        sized = bounds.size
        let count = w < MOBILE_BREAKPOINT ? POINT_COUNT_MOBILE : POINT_COUNT_DESKTOP
        let cols = Int(ceil((Double(count) * (w / h)).squareRoot()))
        let rows = Int(ceil(Double(count) / Double(cols)))
        let cellW = w / Double(cols), cellH = h / Double(rows)
        points = (0..<count).map { i in
            let col = i % cols, row = i / cols
            let x = (Double(col) + 0.5) * cellW + Double.random(in: -0.5..<0.5) * cellW * 0.9
            let y = (Double(row) + 0.5) * cellH + Double.random(in: -0.5..<0.5) * cellH * 0.9
            return Point(x: min(max(0, x), w), y: min(max(0, y), h))
        }
        pulses = []
    }

    private func spawnBurst() {
        guard !points.isEmpty else { return }
        var origin = 0, attempts = 0
        repeat {
            origin = Int.random(in: 0..<points.count)
            attempts += 1
        } while attempts < 50 && (points[origin].x < EDGE_MARGIN*2 || points[origin].x > w - EDGE_MARGIN*2
                               || points[origin].y < EDGE_MARGIN*2 || points[origin].y > h - EDGE_MARGIN*2)
        points[origin].activation = min(1, points[origin].activation + 0.5)
        for n in neighbors[origin] { pulses.append(Pulse(origin, n)) }
    }

    override func animateOneFrame() {
        if points.isEmpty || bounds.size != sized { initPoints() }
        guard !points.isEmpty else { return }

        time += animationTimeInterval * 1000
        for i in points.indices { points[i].update(time) }
        neighbors = Delaunay.neighbors(points.map { CGPoint(x: $0.x, y: $0.y) }, width: w, height: h)

        if time - lastBurst > HEARTBEAT_INTERVAL { spawnBurst(); lastBurst = time }

        pulses = pulses.filter { $0.alive }
        var spawned: [Pulse] = []
        for p in pulses { p.update(neighbors: neighbors, points: &points, spawn: &spawned, w: w, h: h) }
        pulses += spawned

        setNeedsDisplay(bounds)
    }

    // MARK: - Drawing

    override func draw(_ rect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        drawBackground(ctx)
        guard !points.isEmpty, neighbors.count == points.count else { return }
        drawCells(ctx)
        drawEdges(ctx)
        drawVignette(ctx)
    }

    private func drawBackground(_ ctx: CGContext) {
        let space = CGColorSpaceCreateDeviceRGB()
        let g = CGGradient(colorsSpace: space, colors: [
            CGColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1),
            CGColor(red: 6/255,  green: 16/255, blue: 24/255, alpha: 1),
            CGColor(red: 2/255,  green: 6/255,  blue: 8/255,  alpha: 1),
        ] as CFArray, locations: [0, 0.5, 1])!
        ctx.drawRadialGradient(g,
            startCenter: CGPoint(x: w * 0.3, y: h * 0.4), startRadius: 0,
            endCenter: CGPoint(x: w * 0.5, y: h * 0.5), endRadius: w * 0.9,
            options: [.drawsAfterEndLocation])
    }

    // Voronoi cell of site i = bounds rect clipped by the perpendicular-bisector
    // half-plane against each Delaunay neighbor. Stroked teal, brighter+thicker with activation.
    private func drawCells(_ ctx: CGContext) {
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for i in points.indices {
            var poly = [CGPoint(x: 0, y: 0), CGPoint(x: w, y: 0), CGPoint(x: w, y: h), CGPoint(x: 0, y: h)]
            let s = CGPoint(x: points[i].x, y: points[i].y)
            for n in neighbors[i] {
                let q = CGPoint(x: points[n].x, y: points[n].y)
                let m = CGPoint(x: (s.x + q.x) / 2, y: (s.y + q.y) / 2)
                let dir = CGPoint(x: q.x - s.x, y: q.y - s.y) // keep side where (p-m)·dir <= 0
                poly = clip(poly, m, dir)
                if poly.count < 3 { break }
            }
            guard poly.count >= 3 else { continue }

            let p = points[i]
            let cellPulse = sin(time * p.breathSpeed * 3 + p.glowPhase)
            let baseAlpha = 0.08 + cellPulse * 0.04
            let alpha = min(MAX_ALPHA, baseAlpha + p.activation * 0.28)
            ctx.setStrokeColor(CGColor(red: 20/255, green: 184/255, blue: 166/255, alpha: alpha))
            ctx.setLineWidth(1 + p.activation * 0.8)
            ctx.beginPath()
            ctx.move(to: poly[0])
            for v in poly.dropFirst() { ctx.addLine(to: v) }
            ctx.closePath()
            ctx.strokePath()
        }
    }

    // Sutherland-Hodgman clip against half-plane { p : (p - m)·dir <= 0 }.
    private func clip(_ poly: [CGPoint], _ m: CGPoint, _ dir: CGPoint) -> [CGPoint] {
        func inside(_ p: CGPoint) -> Double { (p.x - m.x) * dir.x + (p.y - m.y) * dir.y }
        var out: [CGPoint] = []
        for i in poly.indices {
            let a = poly[i], b = poly[(i + 1) % poly.count]
            let da = inside(a), db = inside(b)
            if da <= 0 { out.append(a) }
            if (da < 0) != (db < 0) {
                let t = da / (da - db)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        return out
    }

    private func drawEdges(_ ctx: CGContext) {
        // ponytail: single cyan stroke instead of the web version's 3-stop teal→cyan→purple
        // gradient — on 1px edges at <12% alpha the gradient is imperceptible.
        ctx.setLineWidth(1.2)
        let maxDist = max(w, h) * 0.15
        for i in points.indices {
            for j in neighbors[i] where i < j {     // each undirected edge visited once
                let dx = points[i].x - points[j].x, dy = points[i].y - points[j].y
                let dist = (dx*dx + dy*dy).squareRoot()
                let alpha = max(0, 1 - dist / maxDist) * 0.12
                if alpha < 0.01 { continue }
                ctx.setStrokeColor(CGColor(red: 56/255, green: 189/255, blue: 248/255, alpha: alpha))
                ctx.beginPath()
                ctx.move(to: CGPoint(x: points[i].x, y: points[i].y))
                ctx.addLine(to: CGPoint(x: points[j].x, y: points[j].y))
                ctx.strokePath()
            }
        }
    }

    private func drawVignette(_ ctx: CGContext) {
        let space = CGColorSpaceCreateDeviceRGB()
        let g = CGGradient(colorsSpace: space, colors: [
            CGColor(red: 2/255, green: 6/255, blue: 8/255, alpha: 0),
            CGColor(red: 2/255, green: 6/255, blue: 8/255, alpha: 0.5),
        ] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(g,
            startCenter: CGPoint(x: w * 0.5, y: h * 0.5), startRadius: 0,
            endCenter: CGPoint(x: w * 0.5, y: h * 0.5), endRadius: max(w, h) * 0.7,
            options: [.drawsAfterEndLocation])
    }
}
