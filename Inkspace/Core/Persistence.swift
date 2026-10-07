import Foundation
import CoreGraphics

nonisolated struct Snapshot: Codable, @unchecked Sendable {
    var elements: [Element]
    var offset: CGPoint
    var scale: CGFloat
    var background: Background?
    var showGrid: Bool?
}

nonisolated enum Persistence {
    private static let queue = DispatchQueue(label: "inkspace.persistence", qos: .utility)
    private static let fm = FileManager.default
    private static let interval: TimeInterval = 600
    private static let keep = 10

    private static var root: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private static var legacy: URL { root.appendingPathComponent("note.json") }

    private static func file(_ id: UUID) -> URL {
        let dir = root.appendingPathComponent("Notes", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(id.uuidString).json")
    }

    private static func backupDir(_ id: UUID) -> URL {
        root.appendingPathComponent("Backups", isDirectory: true).appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func adoptLegacy(as id: UUID) -> Bool {
        guard fm.fileExists(atPath: legacy.path) else { return false }
        return (try? fm.moveItem(at: legacy, to: file(id))) != nil
    }

    static func remove(_ id: UUID) {
        try? fm.removeItem(at: file(id))
        try? fm.removeItem(at: backupDir(id))
        removeDocument(id)
    }

    // MARK: - Imported files

    private static var documentsDir: URL {
        root.appendingPathComponent("Files", isDirectory: true)
    }

    private static func documentFile(_ id: UUID, _ fileExtension: String) -> URL {
        let dir = documentsDir
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(id.uuidString).\(fileExtension.lowercased())")
    }

    static func saveDocument(_ id: UUID, data: Data, fileExtension: String) -> Bool {
        let ext = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        guard !ext.isEmpty else { return false }

        removeDocument(id)

        do {
            try data.write(to: documentFile(id, ext), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func loadDocument(_ id: UUID) -> (data: Data, fileExtension: String)? {
        let urls = (try? fm.contentsOfDirectory(
            at: documentsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        guard let url = urls.first(where: {
            $0.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(id.uuidString) == .orderedSame
        }),
        let data = try? Data(contentsOf: url) else {
            return nil
        }

        return (data, url.pathExtension.lowercased())
    }

    static func removeDocument(_ id: UUID) {
        let urls = (try? fm.contentsOfDirectory(
            at: documentsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        for url in urls where url.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(id.uuidString) == .orderedSame {
            try? fm.removeItem(at: url)
        }
    }

    private static func decode(_ url: URL) -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private static func backupFiles(_ id: UUID) -> [URL] {
        let files = (try? fm.contentsOfDirectory(at: backupDir(id), includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func load(_ id: UUID) -> Snapshot? {
        let url = file(id)
        if let snapshot = decode(url) { return snapshot }
        if fm.fileExists(atPath: url.path) {
            let bad = url.appendingPathExtension("corrupt")
            try? fm.removeItem(at: bad)
            try? fm.moveItem(at: url, to: bad)
        }
        for backup in backupFiles(id) {
            if let snapshot = decode(backup) { return snapshot }
        }
        return nil
    }

    static func save(_ id: UUID, _ snapshot: Snapshot) {
        queue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            rotate(id)
            try? data.write(to: file(id), options: .atomic)
        }
    }

    private static func rotate(_ id: UUID) {
        let url = file(id)
        guard fm.fileExists(atPath: url.path) else { return }
        let dir = backupDir(id)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let now = Date().timeIntervalSince1970
        if let newest = backupFiles(id).first,
           let stamp = TimeInterval(newest.deletingPathExtension().lastPathComponent.dropFirst(5)),
           now - stamp < interval { return }
        try? fm.copyItem(at: url, to: dir.appendingPathComponent("note-\(Int(now)).json"))
        for old in backupFiles(id).dropFirst(keep) { try? fm.removeItem(at: old) }
    }
}
