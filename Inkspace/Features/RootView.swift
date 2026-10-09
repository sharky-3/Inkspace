import SwiftUI

struct RootView: View {
    @StateObject private var library = Library()
    @StateObject private var store = CanvasStore()
    @AppStorage("theme") private var theme = 0
    @AppStorage("keepAwake") private var keepAwake = true

    var body: some View {
        ZStack {
            if let id = library.current {
                ContentView(store: store) {
                    store.persist()
                    library.touch(id)
                    library.current = nil
                }
            } else {
                LibraryView(library: library) { id in
                    store.open(id)
                    library.current = id
                }
            }        }
        .preferredColorScheme(theme == 1 ? .light : theme == 2 ? .dark : nil)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepAwake }
        .onChange(of: keepAwake) { _, value in UIApplication.shared.isIdleTimerDisabled = value }
    }
}
