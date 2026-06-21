import CoreGraphics

// Minimal Delaunay triangulation (Bowyer-Watson) + neighbor adjacency.
// Rebuilt every frame from the breathing point set, same as the web version's
// d3-delaunay. Voronoi cells are derived separately by half-plane clipping
// (see BioElectricView), which needs only the neighbor lists below.

struct Tri { var a, b, c: Int }

enum Delaunay {
    // True if d lies inside the circumcircle of triangle (a,b,c), orientation-agnostic.
    private static func inCircumcircle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        let ax = a.x - d.x, ay = a.y - d.y
        let bx = b.x - d.x, by = b.y - d.y
        let cx = c.x - d.x, cy = c.y - d.y
        let det = (ax*ax + ay*ay) * (bx*cy - cx*by)
                - (bx*bx + by*by) * (ax*cy - cx*ay)
                + (cx*cx + cy*cy) * (ax*by - bx*ay)
        let orient = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        if orient == 0 { return false } // degenerate / collinear
        return orient > 0 ? det > 0 : det < 0
    }

    /// Neighbor adjacency for every input point (indices into `points`).
    static func neighbors(_ points: [CGPoint], width: Double, height: Double) -> [[Int]] {
        let n = points.count
        guard n >= 3 else { return Array(repeating: [], count: n) }

        // Super-triangle large enough to enclose all (breathing) points.
        let d = max(width, height)
        var pts = points
        pts.append(CGPoint(x: width/2 - 20*d, y: height/2 - d))
        pts.append(CGPoint(x: width/2 + 20*d, y: height/2 - d))
        pts.append(CGPoint(x: width/2,        y: height/2 + 20*d))
        var tris = [Tri(a: n, b: n+1, c: n+2)]

        for i in 0..<n {
            let p = pts[i]
            var kept: [Tri] = []
            var badEdges: [(Int, Int)] = []
            for t in tris {
                if inCircumcircle(pts[t.a], pts[t.b], pts[t.c], p) {
                    badEdges.append((t.a, t.b))
                    badEdges.append((t.b, t.c))
                    badEdges.append((t.c, t.a))
                } else {
                    kept.append(t)
                }
            }
            // Re-triangulate the hole from edges that aren't shared by two bad triangles.
            for (idx, e) in badEdges.enumerated() {
                var shared = false
                for (j, f) in badEdges.enumerated() where j != idx {
                    if (e.0 == f.0 && e.1 == f.1) || (e.0 == f.1 && e.1 == f.0) { shared = true; break }
                }
                if !shared { kept.append(Tri(a: e.0, b: e.1, c: i)) }
            }
            tris = kept
        }

        var sets = Array(repeating: Set<Int>(), count: n)
        for t in tris where t.a < n && t.b < n && t.c < n {
            sets[t.a].insert(t.b); sets[t.a].insert(t.c)
            sets[t.b].insert(t.a); sets[t.b].insert(t.c)
            sets[t.c].insert(t.a); sets[t.c].insert(t.b)
        }
        return sets.map { Array($0) }
    }
}
