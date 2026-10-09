import SwiftUI

struct EditorTile<Icon: View>: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                icon().frame(height: 30)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(selected ? Color.white : Color.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.18) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(selected ? 0.35 : 0), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .animation(.snappy(duration: 0.25), value: selected)
    }
}
