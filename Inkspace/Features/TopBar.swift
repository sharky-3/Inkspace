import SwiftUI
import PhotosUI

struct TopBar: View {
    @ObservedObject var store: CanvasStore
    @Binding var item: PhotosPickerItem?
    let onExport: () -> Void
    let onImport: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            HStack(spacing: 2) {
                IconButton(icon: "arrow.uturn.backward", disabled: store.undoStack.isEmpty) { store.undo() }
                IconButton(icon: "arrow.uturn.forward", disabled: store.redoStack.isEmpty) { store.redo() }
            }
            .padding(6)
            .glass()

            Spacer()

            Text("\(Int(store.scale * 100))%")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .padding(.horizontal, 14)
                .frame(height: 44)
                .glass(16)

            HStack(spacing: 2) {
                Menu {
                    Picker("Background", selection: $store.background) {
                        ForEach(Background.allCases) { b in
                            Label(b.title, systemImage: b.icon).tag(b)
                        }
                    }
                } label: {
                    IconLabel(icon: store.background.icon, active: store.background != .none)
                }
                IconButton(icon: "scope") { store.resetView?() }
                PhotosPicker(selection: $item, matching: .images) { IconLabel(icon: "photo") }
                Menu {
                    Button(action: onExport) {
                        Label("Save backup to Files", systemImage: "square.and.arrow.up")
                    }
                    Button(action: onImport) {
                        Label("Restore from backup", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    IconLabel(icon: "externaldrive")
                }
                IconButton(icon: "trash", disabled: store.elements.isEmpty) { store.clear() }
            }
            .padding(6)
            .glass()
        }
    }
}
