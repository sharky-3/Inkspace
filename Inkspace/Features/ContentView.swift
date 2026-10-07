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

    var body: some View {
        ZStack {
            CanvasView(store: store).ignoresSafeArea()
                .overlay(alignment: .bottom) { SelectionBar(store: store).padding(24) }
            VStack(spacing: 0) {
                TopBar(store: store, onClose: onClose, onExport: export, onImport: { importing = true })
                HStack(alignment: .center, spacing: 10) {
                    if barRight { Spacer(minLength: 0) }
                    if !barRight { ToolBar(store: store, barRight: barRight) }
                    editor
                    if barRight { ToolBar(store: store, barRight: barRight) }
                    if !barRight { Spacer(minLength: 0) }
                }
                .frame(maxHeight: .infinity)
                .animation(.snappy, value: store.editorOpen)
            }
            .padding(16)
            if store.isLoading {
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    ProgressView()
                }
                .zIndex(1)
            }
        }
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

    @ViewBuilder private var editor: some View {
        if store.editorOpen {
            EditorPanel(store: store)
                .padding(.vertical, 10)
                .transition(.move(edge: barRight ? .trailing : .leading).combined(with: .opacity))
        }
    }

    private func export() {
        document = NoteDocument(data: store.exportData())
        exporting = true
    }
}
