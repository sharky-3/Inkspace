import SwiftUI

struct IconLabel: View {
    let icon: String
    var active = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18))
            .frame(width: 44, height: 44)
            .foregroundStyle(active ? Color(uiColor: .systemBackground) : Color.primary)
            .background(active ? Color.primary : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
    }
}

struct IconButton: View {
    let icon: String
    var active = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) { IconLabel(icon: icon, active: active) }
            .disabled(disabled)
            .opacity(disabled ? 0.3 : 1)
    }
}
