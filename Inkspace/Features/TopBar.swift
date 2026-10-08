import SwiftUI

struct TopBar: View {
    
    @ObservedObject var store: CanvasStore
    
    let onClose: () -> Void
    let onExport: () -> Void
    let onImport: () -> Void
    
    var body: some View {
        
        HStack(alignment: .top) {
            
            HStack(spacing: 2) {
                
                IconButton(
                    icon: "square.grid.2x2",
                    action: onClose
                )
                
                IconButton(
                    icon: "arrow.uturn.backward",
                    disabled: store.undoStack.isEmpty
                ) {
                    store.undo()
                }
                
                IconButton(
                    icon: "arrow.uturn.forward",
                    disabled: store.redoStack.isEmpty
                ) {
                    store.redo()
                }
            }
            .padding(6)
            .glass()
            .environment(\.colorScheme, .dark)
            
            Spacer()
            
            // Zoom indicator
            Text("\(Int(store.scale * 100))%")
                .font(
                    .system(
                        size: 13,
                        weight: .medium,
                        design: .monospaced
                    )
                )
                .padding(.horizontal, 14)
                .frame(height: 56)
                .glass(22)
                .environment(\.colorScheme, .dark)
            
            HStack(spacing: 2) {
                
                IconButton(
                    icon: store.background.icon
                ) {
                    cycleBackground()
                }
                
                IconButton(
                    icon: "scope"
                ) {
                    store.resetView?()
                }
                
                PopoverButton(icon: "externaldrive") {
                    
                    MenuRow(
                        icon: "square.and.arrow.up",
                        title: "Save backup to Files",
                        action: onExport
                    )
                    
                    MenuRow(
                        icon: "square.and.arrow.down",
                        title: "Restore from backup",
                        action: onImport
                    )
                }
                
                IconButton(
                    icon: "trash",
                    disabled: store.elements.isEmpty
                ) {
                    store.clear()
                }
            }
            .padding(6)
            .glass()
            .environment(\.colorScheme, .dark)
        }
    }
    
    private func cycleBackground() {
        
        let all = Background.allCases
        
        let next =
        (
            (all.firstIndex(of: store.background) ?? 0)
            + 1
        ) % all.count
        
        store.background = all[next]
    }
}
