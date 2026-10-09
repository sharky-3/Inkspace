import SwiftUI

struct BarButton: View {
    let icon: String
    var active = false
    var dim = false
    var highlight: Namespace.ID? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 21))
                .foregroundStyle(active ? Color.black : Color.white)
                .frame(width: 40, height: 40)
                .background { pill }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(dim)
        .opacity(dim ? 0.3 : 1)
    }

    @ViewBuilder private var pill: some View {
        if active {
            let fill = RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Color.white)
            if let highlight {
                fill.matchedGeometryEffect(id: "highlight", in: highlight)
            } else {
                fill
            }
        }
    }
}
