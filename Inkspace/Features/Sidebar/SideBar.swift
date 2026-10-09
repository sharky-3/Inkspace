import SwiftUI

struct SideBar: View {
    static let width: CGFloat = 75

    @ObservedObject var store: CanvasStore
    let right: Bool
    let top: CGFloat
    let bottom: CGFloat
    let onClose: () -> Void
    @Namespace private var highlight

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                BarButton(icon: "square.grid.2x2", action: onClose)
                BarButton(icon: "arrow.uturn.backward", dim: store.undoStack.isEmpty) { store.undo() }
                BarButton(icon: "arrow.uturn.forward", dim: store.redoStack.isEmpty) { store.redo() }
            }
            Spacer(minLength: 12)
            tools
            Spacer(minLength: 12)
            VStack(spacing: 14) {
                zoom
                swatch
            }
        }
        .padding(.top, top + 24)
        .padding(.bottom, bottom + 24)
        .frame(width: Self.width)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: right ? .leading : .trailing)
        .background(Color.black)
    }

    private var tools: some View {
        VStack(spacing: 6) {
            BarButton(icon: Tool.move.icon, active: store.tool == .move, highlight: highlight) { store.tool = .move }
            BarButton(icon: Tool.eraser.icon, active: store.tool == .eraser, highlight: highlight) { store.tool = .eraser }
            BarButton(icon: store.brush.icon, active: store.tool == .brush, highlight: highlight) { pick(.brush) }
            BarButton(icon: store.shape.icon, active: store.tool.isShape, highlight: highlight) { pick(store.shape) }
            BarButton(icon: Tool.text.icon, active: store.tool == .text, highlight: highlight) { store.tool = .text }
        }
        .padding(6)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(.snappy(duration: 0.35), value: store.tool)
        .sensoryFeedback(.selection, trigger: store.tool)
    }

    private var zoom: some View {
        Button { store.resetView?() } label: {
            Text("\(Int(store.scale * 100))%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(width: 56, height: 28)
                .background(Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(PressStyle())
    }

    private var swatch: some View {
        Button {
            store.menuAnchor = nil
            store.editorOpen.toggle()
        } label: {
            Circle()
                .fill(Color(uiColor: store.color))
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 2))
                .padding(7)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func pick(_ tool: Tool) {
        if store.tool == tool || (tool.isShape && store.tool.isShape) {
            store.menuAnchor = nil
            store.editorOpen = true
        } else {
            store.tool = tool
        }
    }
}
