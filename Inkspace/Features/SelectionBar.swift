import SwiftUI

struct SelectionBar: View {
    @ObservedObject var store: CanvasStore

    var body: some View {
        if store.tool == .move, !store.selection.isEmpty {
            HStack(spacing: 2) {
                IconButton(icon: "plus.square.on.square") { store.duplicateSelection() }
                IconButton(icon: "trash") { store.deleteSelection() }
            }
            .padding(6)
            .glass()
        }
    }
}
