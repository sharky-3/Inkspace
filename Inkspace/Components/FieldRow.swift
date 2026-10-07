import SwiftUI

struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.secondary)
                .frame(width: 64, alignment: .leading)
            HStack(spacing: 8) { content() }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
        }
    }
}
