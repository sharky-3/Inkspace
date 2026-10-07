import SwiftUI

struct BrushPreview: View {
    let brush: Brush

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            path.move(to: CGPoint(x: 4, y: size.height / 2))
            path.addCurve(
                to: CGPoint(x: size.width - 4, y: size.height / 2),
                control1: CGPoint(x: size.width * 0.3, y: -size.height * 0.2),
                control2: CGPoint(x: size.width * 0.6, y: size.height * 1.2)
            )
            let w = min(max(2, 3 * brush.widthScale), 14)
            let color = GraphicsContext.Shading.color(Color.primary.opacity(brush.alpha))
            if brush.variable {
                for i in 0..<20 {
                    let t = Double(i) / 20
                    let k = brush == .calligraphy ? 0.4 + 1.4 * abs(sin(t * .pi * 2)) : 0.3 + 1.7 * sin(t * .pi)
                    ctx.stroke(path.trimmedPath(from: t, to: min(t + 0.06, 1)), with: color,
                               style: StrokeStyle(lineWidth: w * k, lineCap: .round))
                }
            } else {
                ctx.stroke(path, with: color, style: StrokeStyle(
                    lineWidth: w,
                    lineCap: brush.cap == .butt ? .butt : .round,
                    lineJoin: .round,
                    dash: brush.dash(w)
                ))
            }
        }
        .frame(width: 64, height: 34)
    }
}
