import UIKit

enum ElementRenderer {
    static let pointsPerCm: CGFloat = 52
    static var dark = false

    private static func ink(_ c: UIColor) -> UIColor {
        guard dark else { return c }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: nil)
        return (r + g + b) / 3 < 0.25 ? UIColor(white: 0.96, alpha: 1) : c
    }

    static func draw(_ e: Element, in ctx: CGContext) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        let width = e.width * e.brush.widthScale
        ctx.setStrokeColor(ink(e.color).withAlphaComponent(e.brush.alpha).cgColor)
        ctx.setLineCap(e.brush.cap)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(width)
        ctx.setLineDash(phase: 0, lengths: e.brush.dash(width))

        switch e.kind {
        case .stroke:
            if e.brush.variable {
                for i in 1..<e.points.count {
                    ctx.setLineWidth(segmentWidth(e, i))
                    ctx.move(to: e.points[i - 1])
                    ctx.addLine(to: e.points[i])
                    ctx.strokePath()
                }
            } else {
                ctx.addLines(between: e.points)
                ctx.strokePath()
            }
        case .line:
            ctx.move(to: e.points[0])
            ctx.addLine(to: e.points[1])
            ctx.strokePath()
        case .rectangle:
            ctx.stroke(span(e))
        case .ellipse:
            ctx.strokeEllipse(in: span(e))
        case .polygon:
            ctx.addLines(between: e.points)
            ctx.closePath()
            ctx.strokePath()
        case .template:
            ctx.addLines(between: e.template.points(in: span(e)))
            ctx.closePath()
            ctx.strokePath()
        case .ruler:
            drawRuler(e, in: ctx)
        case .text:
            (e.text as NSString).draw(at: e.rect.origin, withAttributes: [.font: e.font, .foregroundColor: ink(e.color)])
        case .image:
            e.image?.draw(in: e.rect)
        }
    }

    private static func segmentWidth(_ e: Element, _ i: Int) -> CGFloat {
        guard e.brush == .calligraphy else { return e.widths[min(i, e.widths.count - 1)] }
        let a = e.points[max(0, i - 4)], b = e.points[i]
        let angle = atan2(b.y - a.y, b.x - a.x)
        return e.width * e.brush.widthScale * (0.15 + 1.6 * abs(sin(angle - .pi / 4)))
    }

    private static func span(_ e: Element) -> CGRect {
        let a = e.points[0], b = e.points[1]
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private static func drawRuler(_ e: Element, in ctx: CGContext) {
        let a = e.points[0], b = e.points[1]
        let dx = b.x - a.x, dy = b.y - a.y
        let length = hypot(dx, dy)
        guard length > 0 else { return }
        let ux = dx / length, uy = dy / length
        ctx.move(to: a)
        ctx.addLine(to: b)
        for i in 0...Int(length / pointsPerCm) {
            let d = CGFloat(i) * pointsPerCm
            let p = CGPoint(x: a.x + ux * d, y: a.y + uy * d)
            ctx.move(to: CGPoint(x: p.x - uy * 7, y: p.y + ux * 7))
            ctx.addLine(to: CGPoint(x: p.x + uy * 7, y: p.y - ux * 7))
        }
        ctx.strokePath()
        var angle = atan2(-dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        let label = String(format: "%.1f cm   %.0f°", length / pointsPerCm, angle)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .medium),
            .foregroundColor: ink(e.color)
        ]
        (label as NSString).draw(at: CGPoint(x: (a.x + b.x) / 2 + 10, y: (a.y + b.y) / 2 + 10), withAttributes: attrs)
    }
}
