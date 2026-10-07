import SwiftUI

@main
struct InkspaceApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
