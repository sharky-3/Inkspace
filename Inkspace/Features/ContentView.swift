import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: CanvasStore
    let onClose: () -> Void
    @Environment(\.scenePhase) private var phase
    @AppStorage("barRight") private var barRight = true
    @State private var draft = ""
    @State private var document = NoteDocument()
    @State private var exporting = false
    @State private var importing = false
    @State private var restoreFailed = false

    private let radius: CGFloat = 50

    var body: some View {
        GeometryReader { geo in
            let safe = geo.safeAreaInsets
            let edge = barRight ? safe.trailing : safe.leading
            let span = SideBar.width + edge
            ZStack(alignment: barRight ? .trailing : .leading) {
                Color.black
                canvas(safe: safe)
                    .padding(barRight ? .trailing : .leading, span)
                SideBar(store: store, right: barRight, top: safe.top, bottom: safe.bottom, onClose: onClose)
                    .frame(width: span)
                if store.isLoading {
                    ZStack {
                        Color.black
                        ProgressView().tint(.white)
                    }
                    .zIndex(1)
                }
            }
            .ignoresSafeArea()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: barRight)
        .animation(.spring(response: 0.45, dampingFraction: 0.84), value: store.editorOpen)
        .animation(.easeOut(duration: 0.4), value: store.isLoading)
        .onChange(of: phase) { _, new in
            if new != .active { store.persist() }
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Inkspace Backup") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), store.restore(from: data) else {
                restoreFailed = true
                return
            }
        }
        .alert("Couldn't read that backup", isPresented: $restoreFailed) {
            Button("OK", role: .cancel) {}
        }
        .alert("Text", isPresented: Binding(
            get: { store.textRequest != nil },
            set: { if !$0 { store.textRequest = nil } }
        )) {
            TextField("Type here", text: $draft)
            Button("Add") {
                store.addText(draft)
                draft = ""
            }
            Button("Cancel", role: .cancel) { draft = "" }
        }
    }

    private var canvasShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: barRight ? 0 : radius,
            bottomLeadingRadius: barRight ? 0 : radius,
            bottomTrailingRadius: barRight ? radius : 0,
            topTrailingRadius: barRight ? radius : 0,
            style: .continuous
        )
    }

    private func canvas(safe: EdgeInsets) -> some View {
        CanvasView(store: store)
            .clipShape(canvasShape)
            .overlay(alignment: .bottom) { SelectionBar(store: store).padding(24) }
            .overlay(alignment: barRight ? .trailing : .leading) {
                if store.editorOpen {
                    EditorSheet(store: store, onExport: export, onImport: { importing = true })
                        .padding(14)
                        .padding(.top, safe.top)
                        .padding(.bottom, safe.bottom)
                        .transition(.move(edge: barRight ? .trailing : .leading).combined(with: .opacity))
                }
            }
    }

    private func export() {
        document = NoteDocument(data: store.exportData())
        exporting = true
    }
}
