import Foundation
import CoreGraphics

struct Snapshot: Codable {
    var elements: [Element]
    var offset: CGPoint
    var scale: CGFloat
    var background: Background?
    var showGrid: Bool?
}

enum Persistence {
    private static let queue = DispatchQueue(label: "inkspace.persistence", qos: .utility)

    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("note.json")
    }

    static func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    static func save(_ snapshot: Snapshot) {
        queue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
