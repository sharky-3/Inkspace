import UIKit

enum Tool: String, CaseIterable, Identifiable {
    case brush, eraser, move, line, rectangle, ellipse, ruler, text

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .brush: "pencil.tip"
        case .eraser: "eraser"
        case .move: "hand.point.up.left"
        case .line: "line.diagonal"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .ruler: "ruler"
        case .text: "textformat"
        }
    }

    var isShape: Bool { [.line, .rectangle, .ellipse, .ruler].contains(self) }
}

enum Brush: String, CaseIterable, Identifiable, Codable {
    case fountain, ballpoint, brush, calligraphy, pencil, marker, highlighter, dashed, dotted

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var widthScale: CGFloat {
        switch self {
        case .ballpoint: 0.8
        case .brush: 1.6
        case .calligraphy: 1.4
        case .pencil: 0.7
        case .marker: 2.5
        case .highlighter: 6
        default: 1
        }
    }

    var alpha: CGFloat {
        switch self {
        case .highlighter: 0.3
        case .pencil: 0.75
        default: 1
        }
    }

    var cap: CGLineCap { self == .highlighter ? .butt : .round }

    var pressureRange: ClosedRange<CGFloat> {
        switch self {
        case .fountain: 0.4...1.6
        case .brush: 0.15...2.4
        default: 1...1
        }
    }

    var variable: Bool { self == .fountain || self == .brush || self == .calligraphy }

    func dash(_ w: CGFloat) -> [CGFloat] {
        switch self {
        case .dashed: [w * 3, w * 2.5]
        case .dotted: [0.01, w * 2.5]
        default: []
        }
    }
}

struct Element: Identifiable {
    enum Kind: String, Codable { case stroke, line, rectangle, ellipse, polygon, ruler, text, image }

    var id = UUID()
    var kind: Kind
    var points: [CGPoint] = []
    var widths: [CGFloat] = []
    var color: UIColor = .black
    var width: CGFloat = 3
    var brush: Brush = .fountain
    var text = ""
    var fontFamily = "Helvetica Neue"
    var fontSize: CGFloat = 28
    var image: UIImage?
    var imageData: Data?
    var rect: CGRect = .zero
}

extension Element {
    var font: UIFont {
        UIFont(descriptor: UIFontDescriptor(fontAttributes: [.family: fontFamily]), size: fontSize)
    }

    var bounds: CGRect {
        switch kind {
        case .text:
            return CGRect(origin: rect.origin, size: (text as NSString).size(withAttributes: [.font: font]))
        case .image:
            return rect
        default:
            guard let first = points.first else { return .zero }
            let box = points.reduce(CGRect(origin: first, size: .zero)) {
                $0.union(CGRect(origin: $1, size: .zero))
            }
            return box.insetBy(dx: -width, dy: -width)
        }
    }

    mutating func move(by d: CGSize) {
        points = points.map { CGPoint(x: $0.x + d.width, y: $0.y + d.height) }
        rect.origin.x += d.width
        rect.origin.y += d.height
    }

    func hit(_ p: CGPoint, tol: CGFloat) -> Bool {
        if kind == .stroke {
            return points.contains { hypot($0.x - p.x, $0.y - p.y) < tol + width }
        }
        return bounds.insetBy(dx: -tol, dy: -tol).contains(p)
    }
}

extension Element: Codable {
    enum CodingKeys: String, CodingKey {
        case id, kind, points, widths, color, width, brush, text, fontFamily, fontSize, imageData, rect
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(kind: try c.decode(Kind.self, forKey: .kind))
        id = try c.decode(UUID.self, forKey: .id)
        points = try c.decode([CGPoint].self, forKey: .points)
        widths = try c.decode([CGFloat].self, forKey: .widths)
        let rgba = try c.decode([CGFloat].self, forKey: .color)
        color = UIColor(red: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3])
        width = try c.decode(CGFloat.self, forKey: .width)
        brush = try c.decode(Brush.self, forKey: .brush)
        text = try c.decode(String.self, forKey: .text)
        fontFamily = try c.decode(String.self, forKey: .fontFamily)
        fontSize = try c.decode(CGFloat.self, forKey: .fontSize)
        rect = try c.decode(CGRect.self, forKey: .rect)
        imageData = try c.decodeIfPresent(Data.self, forKey: .imageData)
        image = imageData.flatMap { UIImage(data: $0) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(points, forKey: .points)
        try c.encode(widths, forKey: .widths)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        try c.encode([r, g, b, a], forKey: .color)
        try c.encode(width, forKey: .width)
        try c.encode(brush, forKey: .brush)
        try c.encode(text, forKey: .text)
        try c.encode(fontFamily, forKey: .fontFamily)
        try c.encode(fontSize, forKey: .fontSize)
        try c.encode(rect, forKey: .rect)
        try c.encodeIfPresent(imageData, forKey: .imageData)
    }
}

enum Background: String, CaseIterable, Identifiable, Codable {
    case none, dots, lines, grid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Blank"
        case .dots: "Dots"
        case .lines: "Lines"
        case .grid: "Grid"
        }
    }

    var icon: String {
        switch self {
        case .none: "square"
        case .dots: "circle.grid.3x3"
        case .lines: "line.3.horizontal"
        case .grid: "square.grid.3x3"
        }
    }
}
