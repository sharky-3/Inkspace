import SwiftUI

struct PopoverButton<Content: View>: View {
    let icon: String
    var edge: Edge = .top
    @ViewBuilder let content: () -> Content
    @State private var open = false

    var body: some View {
        IconButton(icon: icon) { open = true }
            .popover(isPresented: $open, arrowEdge: edge) {
                VStack(alignment: .leading, spacing: 2) { content() }
                    .padding(8)
                    .presentationCompactAdaptation(.popover)
            }
    }
}
