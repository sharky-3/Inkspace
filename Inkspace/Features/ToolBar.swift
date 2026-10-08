import SwiftUI

private struct BarButton: View {
    let icon: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.white)
                .frame(width: 48, height: 48)
                .background(active ? Color(white: 0.22) : Color.clear, in: Circle())
                .contentShape(Circle())
        }
    }
}

struct ToolBar: View {
    @ObservedObject var store: CanvasStore
    let barRight: Bool
    @State private var shapeOpen = false
    @State private var brushOpen = false
    private let shapes: [Tool] = [.line, .rectangle, .ellipse, .ruler]

    var body: some View {
        VStack(spacing: 6) {
            BarButton(icon: Tool.move.icon, active: store.tool == .move) { store.tool = .move }
            BarButton(icon: Tool.eraser.icon, active: store.tool == .eraser) { store.tool = .eraser }
            divider
            BarButton(icon: store.brush.icon, active: store.tool == .brush) {
                if store.tool == .brush { brushOpen = true } else { store.tool = .brush }
            }
            .popover(isPresented: $brushOpen, arrowEdge: barRight ? .trailing : .leading) {
                BrushPopover(store: store).presentationCompactAdaptation(.popover)
            }
            BarButton(icon: store.shape.icon, active: store.tool.isShape) { store.tool = store.shape }
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
                            store.menuAnchor = nil
                            store.editorOpen = true
                        }
                    }
                    .padding(8)
                    .presentationCompactAdaptation(.popover)
                }
            BarButton(icon: Tool.text.icon, active: store.tool == .text) { store.tool = .text }
            divider
            Button {
                store.menuAnchor = nil
                store.editorOpen.toggle()
            } label: {
                Circle()
                    .fill(Color(uiColor: store.color))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Color.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.14)).frame(width: 24, height: 1).padding(.vertical, 4)
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
