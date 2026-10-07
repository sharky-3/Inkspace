import Foundation
import Combine

struct NoteInfo: Identifiable, Codable {
    var id = UUID()
    var title: String
    var folder: UUID?
    var updated = Date()
}

struct FolderInfo: Identifiable, Codable {
    var id = UUID()
    var name: String
}

struct LibraryData: Codable {
    var notes: [NoteInfo] = []
    var folders: [FolderInfo] = []
}

final class Library: ObservableObject {
    @Published var data = LibraryData() { didSet { save() } }
    @Published var current: UUID?

    private var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("library.json")
    }

    init() {
        if let raw = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(LibraryData.self, from: raw) {
            data = decoded
        }
        if data.notes.isEmpty {
            let first = NoteInfo(title: "Untitled")
            if Persistence.adoptLegacy(as: first.id) {
                data.notes = [first]
                save()
            }
        }
    }

    private func save() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: url, options: .atomic)
    }

    private func index(_ id: UUID) -> Int? { data.notes.firstIndex { $0.id == id } }

    func newNote(in folder: UUID?) -> UUID {
        let note = NoteInfo(title: "Untitled", folder: folder)
        data.notes.append(note)
        return note.id
    }

    func addFolder(_ name: String) {
        guard !name.isEmpty else { return }
        data.folders.append(FolderInfo(name: name))
    }

    func rename(_ id: UUID, _ title: String) {
        guard !title.isEmpty, let i = index(id) else { return }
        data.notes[i].title = title
    }

    func move(_ id: UUID, to folder: UUID?) {
        guard let i = index(id) else { return }
        data.notes[i].folder = folder
    }

    func touch(_ id: UUID) {
        guard let i = index(id) else { return }
        data.notes[i].updated = Date()
    }

    func delete(_ id: UUID) {
        data.notes.removeAll { $0.id == id }
        Persistence.remove(id)
    }

    func deleteFolder(_ id: UUID) {
        for i in data.notes.indices where data.notes[i].folder == id { data.notes[i].folder = nil }
        data.folders.removeAll { $0.id == id }
    }
}
