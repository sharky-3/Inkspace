import SwiftUI

struct Chip: View {
    let title: String
    var font: Font = .system(size: 15)
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
                .background(selected ? Color.primary : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.15)))
        }
    }
}
