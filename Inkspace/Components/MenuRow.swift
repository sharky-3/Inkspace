import SwiftUI

struct MenuRow: View {
    @Environment(\.dismiss) private var dismiss
    let icon: String
    let title: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 22)
                Text(title)
                Spacer(minLength: 16)
                if selected { Image(systemName: "checkmark") }
            }
            .font(.system(size: 15))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 12)
            .frame(minWidth: 190, minHeight: 42, alignment: .leading)
            .contentShape(Rectangle())
        }
    }
}
