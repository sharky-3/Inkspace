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
