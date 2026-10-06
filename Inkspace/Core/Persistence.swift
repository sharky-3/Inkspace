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

    private static var folder: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static var url: URL { folder.appendingPathComponent("note.json") }
    private static var corrupt: URL { folder.appendingPathComponent("note.corrupt.json") }
    private static var backups: URL { folder.appendingPathComponent("Backups", isDirectory: true) }

    private static func decode(_ file: URL) -> Snapshot? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private static func backupFiles() -> [URL] {
        let files = (try? fm.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func load() -> Snapshot? {
        if let snapshot = decode(url) { return snapshot }
        if fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: corrupt)
            try? fm.moveItem(at: url, to: corrupt)
        }
        for file in backupFiles() {
            if let snapshot = decode(file) { return snapshot }
        }
        return nil
    }

    static func save(_ snapshot: Snapshot) {
        queue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            rotateBackups()
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func rotateBackups() {
        guard fm.fileExists(atPath: url.path) else { return }
        try? fm.createDirectory(at: backups, withIntermediateDirectories: true)
        let now = Date().timeIntervalSince1970
        if let newest = backupFiles().first,
           let stamp = TimeInterval(newest.deletingPathExtension().lastPathComponent.dropFirst(5)),
           now - stamp < interval { return }
        try? fm.copyItem(at: url, to: backups.appendingPathComponent("note-\(Int(now)).json"))
        for old in backupFiles().dropFirst(keep) { try? fm.removeItem(at: old) }
    }
}
