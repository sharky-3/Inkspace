import SwiftUI

struct GlassPanel: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
    }
}

extension View {
    func glass(_ radius: CGFloat = 22) -> some View {
        modifier(GlassPanel(radius: radius))
    }
}
