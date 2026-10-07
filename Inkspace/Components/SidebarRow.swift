import SwiftUI

struct SidebarRow: View {
    let icon: String
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 20)
                Text(title).lineLimit(1)
                Spacer()
            }
            .font(.system(size: 15))
            .padding(.horizontal, 12)
            .frame(height: 40)
            .foregroundStyle(selected ? Color.white : Dark.dim)
            .background(selected ? Color.white.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
