import SwiftUI

struct BrushPreview: View {
    let brush: Brush
    var color: Color = .primary
    var width: CGFloat? = nil
    var size = CGSize(width: 64, height: 34)

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            path.move(to: CGPoint(x: 4, y: size.height / 2))
            path.addCurve(
                to: CGPoint(x: size.width - 4, y: size.height / 2),
                control1: CGPoint(x: size.width * 0.3, y: -size.height * 0.2),
                control2: CGPoint(x: size.width * 0.6, y: size.height * 1.2)
            )
            let w = min(max(1.5, (width ?? 3) * brush.widthScale), size.height * 0.7)
            let shade = GraphicsContext.Shading.color(color.opacity(brush.alpha))
            if brush.variable {
                for i in 0..<20 {
                    let t = Double(i) / 20
                    let k = brush == .calligraphy ? 0.4 + 1.4 * abs(sin(t * .pi * 2)) : 0.3 + 1.7 * sin(t * .pi)
                    ctx.stroke(path.trimmedPath(from: t, to: min(t + 0.06, 1)), with: shade,
                               style: StrokeStyle(lineWidth: w * k, lineCap: .round))
                }
            } else {
                ctx.stroke(path, with: shade, style: StrokeStyle(
                    lineWidth: w,
                    lineCap: brush.cap == .butt ? .butt : .round,
                    lineJoin: .round,
                    dash: brush.dash(w)
                ))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
