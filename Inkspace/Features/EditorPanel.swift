import SwiftUI

enum EditorTab: String, CaseIterable, Identifiable {
    case draw, shapes, text, page

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct EditorPanel: View {
    @ObservedObject var store: CanvasStore
    @AppStorage("barRight") private var barRight = true
    @State private var tab = EditorTab.draw
    private let shapes: [Tool] = [.line, .rectangle, .ellipse, .ruler]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(uiColor: store.color) },
            set: { store.color = UIColor($0) }
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                card {
                    if store.isEditing {
                        Text("Editing \(store.selection.count) selected")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                    SegmentPill(items: EditorTab.allCases, title: { $0.title }, selection: $tab)
                    content
                }
                if tab == .page {
                    card { CollapsibleSection(title: "Gestures") { GestureSettings() } }
                } else {
                    colorCard
                    sizeCard
                }
            }
            .padding(4)
        }
        .frame(width: 330)
        .onChange(of: store.selection) { _, _ in
            guard let kind = store.selectionKind else { return }
            switch kind {
            case .text: tab = .text
            case .stroke: tab = .draw
            case .image: break
            default: tab = .shapes
            }
        }
        .onChange(of: store.tool) { _, t in
            if t == .brush { tab = .draw } else if t == .text { tab = .text } else if t.isShape { tab = .shapes }
        }
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 16) { content() }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(26)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .draw:
            CollapsibleSection(title: "Brushes") { brushGrid(sets: true) }
        case .shapes:
            CollapsibleSection(title: "Shapes") {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(shapes) { s in
                        ItemCell(title: s.title, selected: store.tool == s, action: { store.chooseShape(s) }) {
                            Image(systemName: s.icon).font(.system(size: 22, weight: .light)).foregroundStyle(Color.primary)
                        }
                    }
                }
            }
            CollapsibleSection(title: "Geometry") {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(ShapeTemplate.allCases) { t in
                        ItemCell(title: t.title, selected: store.tool == .template && store.template == t, action: { store.chooseShape(.template, template: t) }) {
                            ShapeIcon(template: t)
                        }
                    }
                }
            }
            CollapsibleSection(title: "Stroke") { brushGrid(sets: false) }
        case .text:
            CollapsibleSection(title: "Fonts") {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Theme.fonts, id: \.self) { f in
                        ItemCell(title: f, selected: store.fontFamily == f, action: {
                            store.fontFamily = f
                            if !store.isEditing { store.tool = .text }
                        }) {
                            Text("Aa").font(.custom(f, size: 26)).foregroundStyle(Color.primary)
                        }
                    }
                }
            }
        case .page:
            CollapsibleSection(title: "Page") {
                SegmentPill(items: Background.allCases, title: { $0.title }, selection: $store.background)
            }
            CollapsibleSection(title: "Tool bar side") {
                SegmentPill(items: [false, true], title: { $0 ? "Right" : "Left" }, selection: $barRight)
            }
        }
    }

    private func brushGrid(sets: Bool) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Brush.allCases) { b in
                ItemCell(title: b.title, selected: store.brush == b && (!sets || store.tool == .brush), action: {
                    store.brush = b
                    if sets && !store.isEditing { store.tool = .brush }
                }) {
                    BrushPreview(brush: b)
                }
            }
        }
    }

    private var colorCard: some View {
        card {
            CollapsibleSection(title: "Color") {
                VStack(spacing: 12) {
                    FieldRow(label: "Palette") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 2) {
                                ForEach(Theme.palette, id: \.self) { c in
                                    ColorSwatch(color: c, selected: store.color == c) { store.color = c }
                                }
                            }
                        }
                    }
                    FieldRow(label: "Custom") {
                        ColorPicker("", selection: colorBinding, supportsOpacity: false).labelsHidden()
                        Text(store.color.hex).font(.system(size: 14, design: .monospaced))
                    }
                }
            }
        }
    }

    private var sizeCard: some View {
        card {
            CollapsibleSection(title: "Options") {
                FieldRow(label: "Size") {
                    if tab == .text {
                        Slider(value: $store.fontSize, in: 12...120).tint(.primary)
                        Text("\(Int(store.fontSize))").font(.system(size: 13, design: .monospaced)).frame(width: 30)
                    } else {
                        Slider(value: $store.width, in: 1...24).tint(.primary)
                        Text("\(Int(store.width))").font(.system(size: 13, design: .monospaced)).frame(width: 30)
                    }
                }
            }
        }
    }
}

enum MenuPane: Hashable { case brushes, colors, size, shapes, fonts, page }

struct EditorMenu: View {
    enum Mode { case card, rail }

    @ObservedObject var store: CanvasStore
    let flip: Bool
    var mode: Mode = .rail
    @State private var pane: MenuPane?

    private struct Entry: Identifiable {
        let id: MenuPane
        let title: String
        let icon: String
    }

    private let entries = [
        Entry(id: .brushes, title: "Brushes", icon: "pencil.tip"),
        Entry(id: .colors, title: "Colors", icon: "paintpalette"),
        Entry(id: .size, title: "Size", icon: "slider.horizontal.3"),
        Entry(id: .shapes, title: "Shapes", icon: "square.on.circle"),
        Entry(id: .fonts, title: "Fonts", icon: "textformat"),
        Entry(id: .page, title: "Page", icon: "square.grid.3x3")
    ]

    private static let rowCount: [MenuPane: Int] = [.brushes: 9, .colors: 9, .size: 2, .shapes: 14, .fonts: 8, .page: 4]

    private static let details: [Brush: String] = [
        .fountain: "ink", .ballpoint: "even", .brush: "press", .pencil: "tilt",
        .highlighter: "glow", .marker: "bold", .calligraphy: "nib", .dashed: "dash", .dotted: "dots"
    ]

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(uiColor: store.color) },
            set: { store.color = UIColor($0) }
        )
    }

    private var rowH: CGFloat { mode == .card ? 44 : 52 }
    private var barWidth: CGFloat { mode == .card ? 230 : 64 }
    private var gradient: LinearGradient {
        LinearGradient(colors: [Color(white: 0.21), Color(white: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Group {
            if mode == .card { card } else { rail }
        }
        .overlay(alignment: .topLeading) { submenu }
        .environment(\.colorScheme, .dark)
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return VStack(spacing: 0) {
            VStack(spacing: 2) {
                row("Select", selected: store.tool == .move, leading: { sym(Tool.move.icon) }) { store.tool = .move; pane = nil }
                row("Eraser", selected: store.tool == .eraser, leading: { sym(Tool.eraser.icon) }) { store.tool = .eraser; pane = nil }
                row("Brushes", selected: store.tool == .brush || pane == .brushes, chevron: true, leading: { sym(store.brush.icon) }) {
                    if store.tool == .brush { toggle(.brushes) } else { store.tool = .brush; pane = nil }
                }
                row("Shapes", selected: store.tool.isShape || pane == .shapes, chevron: true, leading: { sym(store.shape.icon) }) {
                    if store.tool.isShape { toggle(.shapes) } else { store.tool = store.shape; pane = nil }
                }
                row("Text", selected: store.tool == .text, leading: { sym(Tool.text.icon) }) { store.tool = .text; pane = nil }
            }
            .padding(8)
            rule
            VStack(spacing: 2) {
                ForEach(entries.filter { $0.id != .brushes && $0.id != .shapes }) { e in
                    row(e.title, selected: pane == e.id, chevron: true, leading: { sym(e.icon) }) { toggle(e.id) }
                }
            }
            .padding(8)
            rule
            VStack(spacing: 2) {
                row("Undo", dim: store.undoStack.isEmpty, leading: { sym("arrow.uturn.backward") }) { store.undo() }
                row("Redo", dim: store.redoStack.isEmpty, leading: { sym("arrow.uturn.forward") }) { store.redo() }
            }
            .padding(8)
            footer
        }
        .frame(width: barWidth)
        .background(gradient, in: shape)
        .clipShape(shape)
        .overlay(shape.stroke(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.35), radius: 30, y: 14)
    }

    private var rail: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return VStack(spacing: 6) {
            ForEach(entries) { e in
                railButton(e.icon, active: pane == e.id) { toggle(e.id) }
            }
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 24, height: 1).padding(.vertical, 4)
            railButton("arrow.uturn.backward", dim: store.undoStack.isEmpty) { store.undo() }
            railButton("arrow.uturn.forward", dim: store.redoStack.isEmpty) { store.redo() }
        }
        .padding(8)
        .frame(width: barWidth)
        .background(Color(white: 0.03), in: shape)
        .overlay(shape.stroke(Color.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.4), radius: 30, y: 14)
    }

    private func railButton(_ icon: String, active: Bool = false, dim: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.white)
                .frame(width: 48, height: 48)
                .background(active ? Color(white: 0.22) : Color.clear, in: Circle())
                .contentShape(Circle())
                .opacity(dim ? 0.35 : 1)
        }
    }

    private var rule: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
    }

    private var footer: some View {
        HStack {
            Text(store.isEditing ? "EDITING SELECTION" : "\(store.brush.title.uppercased()) · \(Int(store.width))")
            Spacer()
            Text("TAP TO CHOOSE")
        }
        .font(.system(size: 11, design: .monospaced))
        .tracking(1)
        .foregroundStyle(Color.white.opacity(0.45))
        .padding(.horizontal, 18)
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
    }

    private func toggle(_ p: MenuPane) { pane = pane == p ? nil : p }

    private func submenuY(_ p: MenuPane) -> CGFloat {
        let step = rowH + 2
        if mode == .rail { return 8 + CGFloat(entries.firstIndex { $0.id == p } ?? 0) * 54 }
        switch p {
        case .brushes: return 8 + 2 * step
        case .shapes: return 8 + 3 * step
        default:
            let rest = entries.filter { $0.id != .brushes && $0.id != .shapes }
            return 8 + 5 * step + 17 + CGFloat(rest.firstIndex { $0.id == p } ?? 0) * step
        }
    }

    @ViewBuilder private var submenu: some View {
        if let pane {
            let height = min(CGFloat(Self.rowCount[pane] ?? 6) * (rowH + 2) + 16, 430)
            let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) { content(for: pane) }.padding(8)
            }
            .frame(width: 270, height: height)
            .background(gradient, in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.1)))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 10)
            .offset(x: flip ? -282 : barWidth + 12, y: submenuY(pane))
            .transition(.opacity)
        }
    }

    @ViewBuilder private func content(for pane: MenuPane) -> some View {
        switch pane {
        case .brushes:
            ForEach(Brush.allCases) { b in
                row(b.title, selected: store.brush == b, detail: Self.details[b] ?? "", leading: {
                    BrushPreview(brush: b, color: .white, width: 3, size: CGSize(width: 40, height: 24))
                }) {
                    store.brush = b
                    if !store.isEditing { store.tool = .brush }
                    close()
                }
            }
        case .colors:
            ForEach(Theme.palette, id: \.self) { c in
                row(c.hex, selected: store.color == c, font: .system(size: 16, design: .monospaced), leading: {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(uiColor: c))
                        .frame(width: 28, height: 28)
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.white.opacity(0.25)))
                }) {
                    store.color = c
                    close()
                }
            }
            ColorPicker(selection: colorBinding, supportsOpacity: false) {
                Text("Custom").font(.system(size: 17)).foregroundStyle(Color.white)
            }
            .padding(.horizontal, 12)
            .frame(height: rowH)
        case .size:
            VStack(alignment: .leading, spacing: 10) {
                Text(store.tool == .text ? "FONT SIZE" : "STROKE SIZE")
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.45))
                if store.tool == .text {
                    ValueSlider(icon: "textformat.size", value: $store.fontSize, range: 12...120)
                } else {
                    ValueSlider(icon: "scribble", value: $store.width, range: 1...24)
                }
            }
            .padding(12)
        case .shapes:
            ForEach([Tool.line, .rectangle, .ellipse, .ruler]) { s in
                row(s.title, selected: store.tool == s, leading: { sym(s.icon) }) {
                    store.chooseShape(s)
                    close()
                }
            }
            ForEach(ShapeTemplate.allCases) { t in
                row(t.title, selected: store.tool == .template && store.template == t, leading: { ShapeIcon(template: t) }) {
                    store.chooseShape(.template, template: t)
                    close()
                }
            }
        case .fonts:
            ForEach(Theme.fonts, id: \.self) { f in
                row(f, selected: store.fontFamily == f, detail: "\(Int(store.fontSize))", font: .custom(f, size: 17), leading: {
                    Text("Aa").font(.custom(f, size: 20)).foregroundStyle(Color.white)
                }) {
                    store.fontFamily = f
                    if !store.isEditing { store.tool = .text }
                    close()
                }
            }
        case .page:
            ForEach(Background.allCases) { b in
                row(b.title, selected: store.background == b, leading: { sym(b.icon) }) {
                    store.background = b
                    close()
                }
            }
        }
    }

    private func close() {
        if mode == .rail { store.editorOpen = false } else { pane = nil }
    }

    private func sym(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 18)).foregroundStyle(Color.white.opacity(0.9))
    }

    private func row<L: View>(
        _ title: String,
        selected: Bool = false,
        dim: Bool = false,
        chevron: Bool = false,
        detail: String = "",
        font: Font = .system(size: 17),
        @ViewBuilder leading: () -> L,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                leading().frame(width: 40, alignment: .center)
                Text(title).font(font).foregroundStyle(Color.white).lineLimit(1)
                Spacer(minLength: 8)
                if !detail.isEmpty {
                    Text(detail).font(.system(size: 14, design: .monospaced)).foregroundStyle(Color.white.opacity(0.45))
                }
                if chevron {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: rowH)
            .background(selected ? Color.white.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
            .opacity(dim ? 0.35 : 1)
        }
        .buttonStyle(.plain)
    }
}
