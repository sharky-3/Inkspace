import SwiftUI

struct CollapsibleSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @State private var open = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { withAnimation(.snappy) { open.toggle() } } label: {
                HStack {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(open ? 0 : -90))
                }
                .foregroundStyle(Color.primary)
                .contentShape(Rectangle())
            }
            if open { content() }
        }
    }
}
