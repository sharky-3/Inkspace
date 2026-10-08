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
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1)
                pane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .systemBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.06), radius: 24, y: 10)
            .padding(28)
        }
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

    @ViewBuilder private var pane: some View {
        switch page {
        case .settings: SettingsView()
        case .about: AboutView()
        default: grid
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .tracking(0.6)
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                AppLogo(size: 30)
                Text("Inkspace").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.primary)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 14)
            heading("Library")
            SidebarRow(icon: "square.grid.2x2", title: "Notes & Files", selected: page == .all) { page = .all }
            if !library.data.folders.isEmpty { heading("Folders") }
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
            heading("App")
            SidebarRow(icon: "gearshape", title: "Settings", selected: page == .settings) { page = .settings }
            SidebarRow(icon: "info.circle", title: "About", selected: page == .about) { page = .about }
        }
        .padding(16)
        .frame(width: 240)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Text("Notes & Files").foregroundStyle(Color.primary)
                if let id = folderID, let f = library.data.folders.first(where: { $0.id == id }) {
                    Text("/ \(f.name)").foregroundStyle(Color.secondary)
                }
                Spacer()
                Chip(title: "New folder", selected: false) { naming = .folder }
                Chip(title: "Add file", selected: false) { importingFile = true }
                Chip(title: "New note", selected: true) { open(library.newNote(in: folderID)) }
            }
            .font(.system(size: 22, weight: .semibold))
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 16)], spacing: 16) {
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
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
