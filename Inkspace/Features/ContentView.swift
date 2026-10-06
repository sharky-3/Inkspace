import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = CanvasStore()
    @Environment(\.scenePhase) private var phase
    @State private var draft = ""
    @State private var item: PhotosPickerItem?
    @State private var document = NoteDocument()
    @State private var exporting = false
    @State private var importing = false
    @State private var restoreFailed = false

    var body: some View {
        ZStack {
            CanvasView(store: store).ignoresSafeArea()
            VStack {
                TopBar(store: store, item: $item, onExport: export, onImport: { importing = true })
                Spacer()
                VStack(spacing: 12) {
                    SettingsPanel(store: store)
                    ToolBar(store: store)
                }
            }
            .padding(16)
            if store.isLoading {
                LoadingView().transition(.opacity).zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.4), value: store.isLoading)
        .task { store.load() }
        .onChange(of: phase) { _, new in
            if new != .active { store.persist() }
        }
        .onChange(of: item) { _, new in
            guard let new else { return }
            Task {
                if let data = try? await new.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    store.addImage(image)
                }
                item = nil
            }
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

    private func export() {
        document = NoteDocument(data: store.exportData())
        exporting = true
    }
}
