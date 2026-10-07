import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var library: Library
    let open: (UUID) -> Void

    private enum Page: Hashable { case all, folder(UUID), settings, about }
    private enum Naming { case folder, note(UUID) }

    @State private var page = Page.all
    @State private var naming: Naming?
    @State private var draft = ""
    @State private var importingFile = false
    @State private var importFailed = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            switch page {
            case .settings: SettingsView()
            case .about: AboutView()
            default: grid
            }
        }
        .background(Dark.ground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .alert("Name", isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
            TextField("Name", text: $draft)
            Button("Save") { commitName() }
            Button("Cancel", role: .cancel) { draft = "" }
        }
        .fileImporter(
            isPresented: $importingFile,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            importSelectedFile(result)
        }
        .alert("Couldn't import that file", isPresented: $importFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private var folderID: UUID? {
        if case .folder(let id) = page { return id }
        return nil
    }

    private var notes: [NoteInfo] {
        let all = library.data.notes.filter { folderID == nil || $0.folder == folderID }
        return all.sorted { $0.updated > $1.updated }
    }

    private func commitName() {
        switch naming {
        case .folder: library.addFolder(draft)
        case .note(let id): library.rename(id, draft)
        case nil: break
        }
        naming = nil
        draft = ""
    }

    private func importSelectedFile(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let fileData = try? Data(contentsOf: url) else {
            importFailed = true
            return
        }

        let ext = url.pathExtension.lowercased()
        let supported = ext == "pdf" || UIImage(data: fileData) != nil
        guard supported else {
            importFailed = true
            return
        }

        let title = url.deletingPathExtension().lastPathComponent
        guard let id = library.importFile(
            data: fileData,
            title: title,
            fileExtension: ext.isEmpty ? "bin" : ext,
            in: folderID
        ) else {
            importFailed = true
            return
        }

        open(id)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            AppLogo(size: 40).padding(.bottom, 28)
            SidebarRow(icon: "square.grid.2x2", title: "Notes", selected: page == .all) { page = .all }
            ForEach(library.data.folders) { f in
                SidebarRow(icon: "folder", title: f.name, selected: page == .folder(f.id)) { page = .folder(f.id) }
                    .contextMenu {
                        Button("Delete folder", role: .destructive) {
                            if page == .folder(f.id) { page = .all }
                            library.deleteFolder(f.id)
                        }
                    }
            }
            Spacer()
            Rectangle().fill(Dark.line).frame(height: 1).padding(.vertical, 8)
            SidebarRow(icon: "gearshape", title: "Settings", selected: page == .settings) { page = .settings }
            SidebarRow(icon: "info.circle", title: "About", selected: page == .about) { page = .about }
        }
        .padding(24)
        .frame(width: 250)
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                Text("Notes & Files").foregroundStyle(Dark.dim)
                if let id = folderID, let f = library.data.folders.first(where: { $0.id == id }) {
                    Text("/ \(f.name)").foregroundStyle(Color.white)
                }
                Spacer()
                Chip(title: "New folder", selected: false) { naming = .folder }
                Chip(title: "New note", selected: true) { open(library.newNote(in: folderID)) }
                Chip(title: "Add file", selected: false) { importingFile = true }
            }
            .font(.system(size: 28, weight: .semibold))
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 20)], spacing: 20) {
                    ForEach(notes) { n in
                        NoteCard(note: n) { open(n.id) }
                            .contextMenu {
                                Button("Rename", systemImage: "pencil") {
                                    draft = n.title
                                    naming = .note(n.id)
                                }
                                Menu("Move to") {
                                    Button("No folder") { library.move(n.id, to: nil) }
                                    ForEach(library.data.folders) { f in
                                        Button(f.name) { library.move(n.id, to: f.id) }
                                    }
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) { library.delete(n.id) }
                            }
                    }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
