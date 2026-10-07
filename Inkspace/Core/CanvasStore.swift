import UIKit
import Combine

final class CanvasStore: ObservableObject {
    @Published var elements: [Element] = [] { didSet { version &+= 1 } }
    @Published var undoStack: [[Element]] = []
    @Published var redoStack: [[Element]] = []
    @Published var tool: Tool = .brush
    @Published var brush: Brush = .fountain {
        didSet {
            restyle { if ![.text, .image, .ruler].contains($0.kind) { $0.brush = brush } }
            if !isEditing { loadPreset() }
        }
    }
    @Published var color: UIColor = Theme.palette[0] {
        didSet {
            restyle { if $0.kind != .image { $0.color = color } }
            remember()
        }
    }
    @Published var width: CGFloat = 3 {
        didSet {
            restyle { if ![.text, .image].contains($0.kind) { $0.width = width } }
            remember()
        }
    }
    @Published var fontFamily = Theme.fonts[0] {
        didSet { restyle { if $0.kind == .text { $0.fontFamily = fontFamily } } }
    }
    @Published var fontSize: CGFloat = 28 {
        didSet { restyle { if $0.kind == .text { $0.fontSize = fontSize } } }
    }
    @Published var background: Background = .dots
    @Published var scale: CGFloat = 0.8
    @Published var textRequest: CGPoint?
    @Published var isLoading = true
    @Published var shape: Tool = .line
    @Published var editorOpen = false
    @Published var template: ShapeTemplate = .triangle
    @Published var selection: Set<UUID> = []

    var noteID: UUID?
    var version = 0
    var offset = CGPoint.zero
    var center = CGPoint.zero
    var resetView: (() -> Void)?

    private var bag = Set<AnyCancellable>()
    private let saveTrigger = PassthroughSubject<Void, Never>()
    private var loaded = false

    init() {
        saveTrigger
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.persist() }
            .store(in: &bag)
        Publishers.Merge3(
            $elements.dropFirst().map { _ in () },
            $scale.dropFirst().map { _ in () },
            $background.dropFirst().map { _ in () }
        )
        .sink { [weak self] in self?.requestSave() }
        .store(in: &bag)
        loadPresets()
        loadPreset()
    }

    private var presets: [Brush: BrushPreset] = [:]
    private var syncing = false

    private func remember() {
        guard !syncing, !isEditing else { return }
        presets[brush] = BrushPreset(color: color, width: width)
        savePresets()
    }

    private func loadPreset() {
        let p = presets[brush] ?? BrushPreset.fallback(brush)
        syncing = true
        color = p.color
        width = p.width
        syncing = false
    }

    private func savePresets() {
        var raw: [String: [Double]] = [:]
        for (b, p) in presets {
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0
            p.color.getRed(&r, green: &g, blue: &bl, alpha: nil)
            raw[b.rawValue] = [Double(r), Double(g), Double(bl), Double(p.width)]
        }
        UserDefaults.standard.set(raw, forKey: "brushPresets")
    }

    private func loadPresets() {
        guard let raw = UserDefaults.standard.dictionary(forKey: "brushPresets") as? [String: [Double]] else { return }
        for (key, v) in raw where v.count == 4 {
            if let b = Brush(rawValue: key) {
                presets[b] = BrushPreset(color: UIColor(red: CGFloat(v[0]), green: CGFloat(v[1]), blue: CGFloat(v[2]), alpha: 1), width: CGFloat(v[3]))
            }
        }
    }

    func open(_ id: UUID) {
        persist()
        noteID = id
        loaded = false
        isLoading = true
        elements = []
        undoStack = []
        redoStack = []
        selection = []
        offset = .zero
        scale = 0.8
        Task {
            let result = await Task.detached(priority: .userInitiated) { (Persistence.load(id), Persistence.loadDocument(id)) }.value
            guard noteID == id else { return }
            if let snapshot = result.0 {
                apply(snapshot)
            } else if let file = result.1 {
                seed(id, file.data, file.fileExtension)
            }
            loaded = true
            isLoading = false
        }
    }

    private func seed(_ id: UUID, _ data: Data, _ ext: String) {
        let width: CGFloat = 700
        var items: [Element] = []
        if ext == "pdf", let provider = CGDataProvider(data: data as CFData), let doc = CGPDFDocument(provider) {
            var y: CGFloat = 0
            for n in 1...max(1, doc.numberOfPages) {
                guard let page = doc.page(at: n) else { continue }
                let box = page.getBoxRect(.mediaBox)
                let turned = page.rotationAngle % 180 != 0
                let ratio = turned ? box.width / box.height : box.height / box.width
                var e = Element(kind: .pdf)
                e.doc = id
                e.page = n
                e.rect = CGRect(x: 0, y: y, width: width, height: width * ratio)
                items.append(e)
                y = e.rect.maxY + 24
            }
        } else if let image = UIImage(data: data) {
            let ratio = min(1, 1600 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            let scaled = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            var e = Element(kind: .image)
            e.image = scaled
            e.imageData = scaled.jpegData(compressionQuality: 0.85)
            e.rect = CGRect(x: 0, y: 0, width: width, height: width * size.height / size.width)
            items = [e]
        }
        guard !items.isEmpty else { return }
        offset = CGPoint(x: (UIScreen.main.bounds.width - width * 0.8) / 2, y: 90)
        scale = 0.8
        elements = items
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
        guard loaded, let id = noteID else { return }
        Persistence.save(id, snapshot())
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

    var isEditing: Bool { tool == .move && !selection.isEmpty }
    var selectionKind: Element.Kind? { elements.first { selection.contains($0.id) }?.kind }
    private var lastEdit = Date.distantPast

    private func restyle(_ change: (inout Element) -> Void) {
        guard isEditing else { return }
        if Date().timeIntervalSince(lastEdit) > 1 { commit() }
        lastEdit = Date()
        var all = elements
        for i in all.indices where selection.contains(all[i].id) { change(&all[i]) }
        elements = all
    }

    func chooseShape(_ s: Tool, template t: ShapeTemplate? = nil) {
        if let t { template = t }
        guard isEditing else {
            shape = s
            tool = s
            return
        }
        guard s != .ruler else { return }
        let kind: Element.Kind = s == .line ? .line : s == .rectangle ? .rectangle : s == .ellipse ? .ellipse : .template
        let chosen = template
        restyle {
            if [.line, .rectangle, .ellipse, .template].contains($0.kind) {
                $0.kind = kind
                $0.template = chosen
            }
        }
    }

    func deleteSelection() {
        commit()
        elements.removeAll { selection.contains($0.id) }
        selection = []
    }
    
    func flipSelection(horizontal: Bool) {
        let chosen = elements.filter { selection.contains($0.id) }
        guard let first = chosen.first else { return }
        let box = chosen.dropFirst().reduce(first.bounds) { $0.union($1.bounds) }
        let sx = box.minX + box.maxX
        let sy = box.minY + box.maxY

        func mirror(_ p: CGPoint) -> CGPoint {
            horizontal ? CGPoint(x: sx - p.x, y: p.y) : CGPoint(x: p.x, y: sy - p.y)
        }

        commit()
        var all = elements
        for i in all.indices where selection.contains(all[i].id) {
            var e = all[i]
            let b = e.bounds
            if e.kind == .template {
                let a = e.points[0], c = e.points[1]
                let area = CGRect(x: min(a.x, c.x), y: min(a.y, c.y), width: abs(a.x - c.x), height: abs(a.y - c.y))
                e.points = e.template.points(in: area)
                e.kind = .polygon
            }
            e.points = e.points.map(mirror)
            if e.kind == .text || e.kind == .image {
                e.rect.origin = horizontal
                    ? CGPoint(x: sx - b.maxX, y: e.rect.origin.y)
                    : CGPoint(x: e.rect.origin.x, y: sy - b.maxY)
            }
            all[i] = e
        }
        elements = all
    }

    func duplicateSelection() {
        commit()
        let copies = elements.filter { selection.contains($0.id) }.map { e -> Element in
            var c = e
            c.id = UUID()
            c.move(by: CGSize(width: 24, height: 24))
            return c
        }
        elements.append(contentsOf: copies)
        selection = Set(copies.map(\.id))
    }

    func commit() {
        undoStack.append(elements)
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        selection = []
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
        e.image = image.preparingForDisplay() ?? image
        e.imageData = data
        e.rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        add(e)
        tool = .move
    }
}
