import SwiftUI

enum EditorTab: String, CaseIterable, Identifiable {
    case draw, shapes, text, page

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .draw: "pencil.tip.crop.circle"
        case .shapes: "square.on.circle"
        case .text: "textformat"
        case .page: "slider.horizontal.3"
        }
    }

    static func following(_ tool: Tool) -> EditorTab {
        if tool == .text { return .text }
        if tool.isShape { return .shapes }
        return .draw
    }
}

struct EditorSheet: View {
    @ObservedObject var store: CanvasStore
    let onExport: () -> Void
    let onImport: () -> Void
    @AppStorage("barRight") private var barRight = true
    @State private var tab = EditorTab.draw
    @State private var confirmClear = false
    @Namespace private var tabSpace
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let shapes: [Tool] = [.line, .rectangle, .ellipse, .ruler]
    private let panel = RoundedRectangle(cornerRadius: 36, style: .continuous)

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) { content }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .id(tab)
                    .transition(.opacity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: 348)
        .frame(maxHeight: .infinity)
        .background {
            ZStack {
                panel.fill(.ultraThinMaterial)
                panel.fill(Color.black.opacity(0.4))
            }
        }
        .overlay(
            panel.strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        )
        .clipShape(panel)
        .shadow(color: .black.opacity(0.35), radius: 40, y: 16)
        .environment(\.colorScheme, .dark)
        .animation(.snappy(duration: 0.3), value: tab)
        .onAppear { tab = EditorTab.following(store.tool) }
        .onChange(of: store.tool) { _, t in tab = EditorTab.following(t) }
        .onChange(of: store.selection) { _, _ in
            guard let kind = store.selectionKind else { return }
            switch kind {
            case .text: tab = .text
            case .stroke: tab = .draw
            case .image: break
            default: tab = .shapes
            }
        }
        .confirmationDialog("Clear the whole canvas?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear canvas", role: .destructive) { store.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(EditorTab.allCases) { t in
                        Button { tab = t } label: {
                            Image(systemName: t.icon)
                                .font(.system(size: 17))
                                .foregroundStyle(tab == t ? Color.black : Color.white.opacity(0.7))
                                .frame(width: 46, height: 40)
                                .background {
                                    if tab == t {
                                        Capsule().fill(Color.white).matchedGeometryEffect(id: "tab", in: tabSpace)
                                    }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(4)
                .background(Color.white.opacity(0.08), in: Capsule())
                Spacer(minLength: 0)
                Button { store.editorOpen = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(PressStyle())
            }
            HStack(alignment: .firstTextBaseline) {
                Text(tab.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.white)
                Spacer()
                if store.isEditing {
                    Text("\(store.selection.count) selected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .draw:
            card("Preview") { preview }
            card("Brushes") { brushGrid(sets: true) }
            colorCard
            sizeCard
        case .shapes:
            card("Shapes") {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(shapes) { s in
                        EditorTile(title: s.title, selected: store.tool == s, action: { store.chooseShape(s) }) {
                            Image(systemName: s.icon).font(.system(size: 22, weight: .light)).foregroundStyle(Color.white)
                        }
                    }
                }
            }
            card("Geometry") {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(ShapeTemplate.allCases) { t in
                        EditorTile(title: t.title, selected: store.tool == .template && store.template == t, action: { store.chooseShape(.template, template: t) }) {
                            ShapeIcon(template: t)
                        }
                    }
                }
            }
            card("Stroke") { brushGrid(sets: false) }
            colorCard
            sizeCard
        case .text:
            card("Fonts") {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Theme.fonts, id: \.self) { f in
                        EditorTile(title: f, selected: store.fontFamily == f, action: {
                            store.fontFamily = f
                            if !store.isEditing { store.tool = .text }
                        }) {
                            Text("Aa").font(.custom(f, size: 26)).foregroundStyle(Color.white)
                        }
                    }
                }
            }
            colorCard
            sizeCard
        case .page:
            card("Background") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Background.allCases) { b in
                        EditorTile(title: b.title, selected: store.background == b, action: { store.background = b }) {
                            Image(systemName: b.icon).font(.system(size: 20, weight: .light)).foregroundStyle(Color.white)
                        }
                    }
                }
            }
            card("Tool bar side") {
                SegmentPill(items: [false, true], title: { $0 ? "Right" : "Left" }, selection: $barRight)
            }
            card("Gestures") { GestureSettings() }
            card("Library") {
                VStack(spacing: 8) {
                    actionRow("square.and.arrow.up", "Save backup to Files", action: onExport)
                    actionRow("square.and.arrow.down", "Restore from backup", action: onImport)
                    actionRow("trash", "Clear canvas", destructive: true, disabled: store.elements.isEmpty) { confirmClear = true }
                }
            }
        }
    }

    private func card<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.45))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var paper: Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        store.color.getRed(&r, green: &g, blue: &b, alpha: nil)
        return 0.299 * r + 0.587 * g + 0.114 * b > 0.6 ? Color(white: 0.12) : Color.white
    }

    private var preview: some View {
        BrushPreview(brush: store.brush, color: Color(uiColor: store.color), width: store.width, size: CGSize(width: 280, height: 76))
            .frame(maxWidth: .infinity)
            .background(paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func brushGrid(sets: Bool) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Brush.allCases) { b in
                EditorTile(title: b.title, selected: store.brush == b && (!sets || store.tool == .brush), action: {
                    store.brush = b
                    if sets && !store.isEditing { store.tool = .brush }
                }) {
                    BrushPreview(brush: b, color: Color.white)
                }
            }
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(uiColor: store.color) },
            set: { store.color = UIColor($0) }
        )
    }

    private var colorCard: some View {
        card("Color") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Theme.palette, id: \.self) { c in
                        ColorSwatch(color: c, selected: store.color == c) { store.color = c }
                    }
                }
            }
            HStack {
                ColorPicker("Custom", selection: colorBinding, supportsOpacity: false)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white)
                Text(store.color.hex)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
    }

    private var sizeCard: some View {
        card(tab == .text ? "Font size" : "Stroke size") {
            if tab == .text {
                ValueSlider(icon: "textformat.size", value: $store.fontSize, range: 12...120)
            } else {
                ValueSlider(icon: "scribble", value: $store.width, range: 1...24)
            }
        }
    }

    private func actionRow(_ icon: String, _ title: String, destructive: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 24)
                Text(title)
                Spacer()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(destructive ? Color.red : Color.white)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}
