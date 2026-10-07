import SwiftUI

struct ToolBar: View {
    @ObservedObject var store: CanvasStore
    let barRight: Bool
    @State private var shapeOpen = false
    @State private var brushOpen = false
    private let shapes: [Tool] = [.line, .rectangle, .ellipse, .ruler]

    var body: some View {
        VStack(spacing: 4) {
            tool(.move)
            tool(.eraser)
            divider
            IconButton(icon: store.brush.icon, active: store.tool == .brush) {
                if store.tool == .brush { brushOpen = true } else { store.tool = .brush }
            }
            .popover(isPresented: $brushOpen, arrowEdge: barRight ? .trailing : .leading) {
                BrushPopover(store: store).presentationCompactAdaptation(.popover)
            }
            IconButton(icon: store.shape.icon, active: store.tool.isShape) { store.tool = store.shape }
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in shapeOpen = true })
                .popover(isPresented: $shapeOpen, arrowEdge: barRight ? .trailing : .leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(shapes) { s in
                            MenuRow(icon: s.icon, title: s.title, selected: store.shape == s) {
                                store.shape = s
                                store.tool = s
                            }
                        }
                        MenuRow(icon: "triangle", title: "Geometry", selected: store.shape == .template) {
                            store.shape = .template
                            store.tool = .template
                            store.editorOpen = true
                        }
                    }
                    .padding(8)
                    .presentationCompactAdaptation(.popover)
                }
            tool(.text)
            divider
            IconButton(icon: "slider.horizontal.3", active: store.editorOpen) { store.editorOpen.toggle() }
        }
        .padding(6)
        .glass(26)
    }

    private func tool(_ t: Tool) -> some View {
        IconButton(icon: t.icon, active: store.tool == t) { store.tool = t }
    }

    private var divider: some View {
        Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 24, height: 1).padding(.vertical, 4)
    }
}

struct BrushPopover: View {
    @ObservedObject var store: CanvasStore

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(uiColor: store.color) },
            set: { store.color = UIColor($0) }
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            BrushPreview(brush: store.brush, color: Color(uiColor: store.color), width: store.width, size: CGSize(width: 260, height: 70))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Brush.allCases) { b in
                        IconButton(icon: b.icon, active: store.brush == b) { store.brush = b }
                    }
                }
            }
            ValueSlider(icon: "scribble", value: $store.width, range: 1...24)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Theme.palette, id: \.self) { c in
                        ColorSwatch(color: c, selected: store.color == c) { store.color = c }
                    }
                    ColorPicker("", selection: colorBinding, supportsOpacity: false).labelsHidden()
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
