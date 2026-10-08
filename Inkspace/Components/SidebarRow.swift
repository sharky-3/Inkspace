import SwiftUI

struct SidebarRow: View {
    let icon: String
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).frame(width: 20)
                Text(title).font(.system(size: 14, weight: selected ? .medium : .regular)).lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .foregroundStyle(selected ? Color.primary : Color.primary.opacity(0.7))
            .background(selected ? Color(uiColor: .systemBackground) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(selected ? 0.08 : 0)))
            .shadow(color: .black.opacity(selected ? 0.05 : 0), radius: 3, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
