import SwiftUI

struct SegmentPill<T: Hashable>: View {
    let items: [T]
    let title: (T) -> String
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button { selection = item } label: {
                    Text(title(item))
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .foregroundStyle(selection == item ? Color(uiColor: .systemBackground) : Color.secondary)
                        .background(selection == item ? Color.primary : Color.clear, in: Capsule())
                }
            }
        }
        .padding(4)
        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
    }
}
