import UIKit

enum ShapeRecognizer {
    static func recognize(_ pts: [CGPoint], scale: CGFloat) -> (Element.Kind, [CGPoint])? {
        guard pts.count > 6, let a = pts.first, let b = pts.last else { return nil }
        let box = bounds(pts)
        guard max(box.width, box.height) > 30 / scale else { return nil }
        let length = zip(pts, pts.dropFirst()).reduce(CGFloat(0)) { $0 + dist($1.0, $1.1) }
        let gap = dist(a, b)

        if gap > 0.8 * length {
            let deviation = pts.map { lineDistance($0, a, b) }.max() ?? 0
            if deviation < 0.06 * gap + 3 / scale { return (.line, [a, b]) }
            return nil
        }
        guard gap < 0.25 * length else { return nil }

        let corners = [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.maxY)]
        let e = ellipseError(pts, box)
        let r = rectError(pts, box)
        if e < 0.1 && e <= r { return (.ellipse, corners) }
        if r < 0.07 { return (.rectangle, corners) }

        let eps = 0.06 * max(box.width, box.height)
        var v = simplify(pts, eps)
        if let f = v.first, let l = v.last, dist(f, l) < eps * 2 { v.removeLast() }
        v = dropFlat(v)
        if (3...6).contains(v.count) { return (.polygon, v) }
        return nil
    }

    private static func bounds(_ p: [CGPoint]) -> CGRect {
        p.reduce(CGRect(origin: p[0], size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }

    private static func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private static func lineDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let l = dist(a, b)
        guard l > 0 else { return dist(p, a) }
        return abs((b.x - a.x) * (a.y - p.y) - (a.x - p.x) * (b.y - a.y)) / l
    }

    private static func ellipseError(_ p: [CGPoint], _ box: CGRect) -> CGFloat {
        let rx = box.width / 2, ry = box.height / 2
        guard rx > 0, ry > 0 else { return 1 }
        let total = p.reduce(CGFloat(0)) {
            $0 + abs(hypot(($1.x - box.midX) / rx, ($1.y - box.midY) / ry) - 1)
        }
        return total / CGFloat(p.count)
    }

    private static func rectError(_ p: [CGPoint], _ box: CGRect) -> CGFloat {
        let m = min(box.width, box.height)
        guard m > 0 else { return 1 }
        let total = p.reduce(CGFloat(0)) { s, q in
            s + min(abs(q.x - box.minX), abs(q.x - box.maxX), abs(q.y - box.minY), abs(q.y - box.maxY))
        }
        return total / CGFloat(p.count) / m
    }

    private static func simplify(_ p: [CGPoint], _ eps: CGFloat) -> [CGPoint] {
        guard p.count > 2, let f = p.first, let l = p.last else { return p }
        var index = 0
        var maxDistance: CGFloat = 0
        for i in 1..<(p.count - 1) {
            let d = lineDistance(p[i], f, l)
            if d > maxDistance {
                maxDistance = d
                index = i
            }
        }
        guard maxDistance > eps else { return [f, l] }
        let left = simplify(Array(p[...index]), eps)
        let right = simplify(Array(p[index...]), eps)
        return Array(left.dropLast()) + right
    }

    private static func dropFlat(_ points: [CGPoint]) -> [CGPoint] {
        var v = points
        var changed = true
        while changed && v.count > 3 {
            changed = false
            for i in v.indices {
                let p = v[(i + v.count - 1) % v.count], c = v[i], n = v[(i + 1) % v.count]
                let a1 = atan2(c.y - p.y, c.x - p.x)
                let a2 = atan2(n.y - c.y, n.x - c.x)
                var d = abs(a2 - a1)
                if d > .pi { d = 2 * .pi - d }
                if d < 0.45 {
                    v.remove(at: i)
                    changed = true
                    break
                }
            }
        }
        return v
    }
}
