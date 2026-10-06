import UIKit
import Combine

final class CanvasStore: ObservableObject {
    @Published var elements: [Element] = []
    @Published var undoStack: [[Element]] = []
    @Published var redoStack: [[Element]] = []
    @Published var tool: Tool = .brush
    @Published var brush: Brush = .fountain
    @Published var color: UIColor = Theme.palette[0]
    @Published var width: CGFloat = 3
    @Published var fontFamily = Theme.fonts[0]
    @Published var fontSize: CGFloat = 28
    @Published var background: Background = .dots
    @Published var scale: CGFloat = 1
    @Published var textRequest: CGPoint?
    @Published var isLoading = true

    var offset = CGPoint.zero
    var center = CGPoint.zero
    var resetView: (() -> Void)?

    private var bag = Set<AnyCancellable>()
    private let saveTrigger = PassthroughSubject<Void, Never>()
    private var started = false
    private var loaded = false

    init() {
        saveTrigger
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.persist() }
            .store(in: &bag)
        Publishers.Merge3(
            $elements.dropFirst().map { _ in () },
            $scale.dropFirst().map { _ in () },
            $background.dropFirst().map { _ in () }
        )
        .sink { [weak self] in self?.requestSave() }
        .store(in: &bag)
    }

    func load() {
        guard !started else { return }
        started = true
        Task {
            let begin = Date()
            let snapshot = await Task.detached(priority: .userInitiated) { Persistence.load() }.value
            let remaining = 0.9 - Date().timeIntervalSince(begin)
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            if let snapshot { apply(snapshot) }
            loaded = true
            isLoading = false
        }
    }

    private func apply(_ s: Snapshot) {
        elements = s.elements
        offset = s.offset
        scale = s.scale
        background = s.background ?? ((s.showGrid ?? true) ? .dots : .none)
    }

    private func snapshot() -> Snapshot {
        Snapshot(elements: elements, offset: offset, scale: scale, background: background, showGrid: nil)
    }

    func requestSave() { saveTrigger.send() }

    func persist() {
        guard loaded else { return }
        Persistence.save(snapshot())
    }

    func exportData() -> Data {
        (try? JSONEncoder().encode(snapshot())) ?? Data()
    }

    func restore(from data: Data) -> Bool {
        guard let s = try? JSONDecoder().decode(Snapshot.self, from: data) else { return false }
        commit()
        apply(s)
        resetView?()
        return true
    }

    func commit() {
        undoStack.append(elements)
        redoStack.removeAll()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(elements)
        elements = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(elements)
        elements = next
    }

    func add(_ element: Element) {
        commit()
        elements.append(element)
    }

    func clear() {
        commit()
        elements = []
    }

    func addText(_ string: String) {
        defer { textRequest = nil }
        guard let origin = textRequest, !string.isEmpty else { return }
        var e = Element(kind: .text)
        e.text = string
        e.rect.origin = origin
        e.color = color
        e.fontFamily = fontFamily
        e.fontSize = fontSize
        add(e)
    }

    func addImage(_ original: UIImage) {
        let ratio = min(1, 1600 / max(original.size.width, original.size.height))
        let size = CGSize(width: original.size.width * ratio, height: original.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            original.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let w = min(size.width, 400)
        let h = w * size.height / size.width
        var e = Element(kind: .image)
        e.image = image
        e.imageData = data
        e.rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        add(e)
        tool = .move
    }
}
