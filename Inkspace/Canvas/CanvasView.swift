import SwiftUI

struct CanvasView: UIViewRepresentable {
    @ObservedObject var store: CanvasStore

    func makeUIView(context: Context) -> CanvasUIView {
        CanvasUIView(store: store)
    }

    func updateUIView(_ view: CanvasUIView, context: Context) {
        view.refresh()
    }
}
