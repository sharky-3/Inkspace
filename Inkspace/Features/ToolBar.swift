import SwiftUI

struct ToolBar: View {
    @ObservedObject var store: CanvasStore

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Tool.allCases) { tool in
                IconButton(icon: tool.icon, active: store.tool == tool) { store.tool = tool }
            }
        }
        .padding(6)
        .glass()
    }
}
