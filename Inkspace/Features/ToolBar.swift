import SwiftUI

struct ToolBar: View {
    @ObservedObject var store: CanvasStore
    let barRight: Bool
    @State private var shapeOpen = false
    private let shapes: [Tool] = [.line, .rectangle, .ellipse, .ruler]

    var body: some View {
        VStack(spacing: 4) {
            tool(.move)
            tool(.eraser)
            divider
            tool(.brush)
            IconButton(icon: store.shape.icon, active: store.tool.isShape) { store.tool = store.shape }
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in shapeOpen = true })
                .popover(isPresented: $shapeOpen, arrowEdge: barRight ? .trailing : .leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(shapes) { s in
                            MenuRow(icon: s.icon, title: s.title, selected: store.shape == s) {
                                store.shape = s
                                store.tool = s
                            }
                        }
                        MenuRow(icon: "triangle", title: "Geometry", selected: store.shape == .template) {
                            store.shape = .template
                            store.tool = .template
                            store.editorOpen = true
                        }
                    }
                    .padding(8)
                    .presentationCompactAdaptation(.popover)
                }
            tool(.text)
            divider
            IconButton(icon: "slider.horizontal.3", active: store.editorOpen) { store.editorOpen.toggle() }
        }
        .padding(6)
        .glass(26)
    }

    private func tool(_ t: Tool) -> some View {
        IconButton(icon: t.icon, active: store.tool == t) { store.tool = t }
    }

    private var divider: some View {
        Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 24, height: 1).padding(.vertical, 4)
    }
}
