import SwiftUI

struct GestureSettings: View {
    @AppStorage("undoFingers") private var undo = 2
    @AppStorage("editorFingers") private var editor = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            caption("Undo: double tap with")
            SegmentPill(items: [2, 3, 4], title: { "\($0) fingers" }, selection: $undo)
            caption("Editor: tap with")
            SegmentPill(items: [2, 3, 4], title: { "\($0) fingers" }, selection: $editor)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(Color.secondary)
    }
}
