import SwiftUI

struct ShapeIcon: View {
    let template: ShapeTemplate

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            path.addLines(template.points(in: CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4)))
            path.closeSubpath()
            ctx.stroke(path, with: .color(Color.primary), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
        .frame(width: 34, height: 34)
    }
}
