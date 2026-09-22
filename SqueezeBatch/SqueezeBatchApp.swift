import SwiftUI

@main
struct SqueezeBatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
            }
            CommandGroup(replacing: .newItem) { EmptyView() }
        }

        Window("About SqueezeBatch", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

/// Menu-bar "About SqueezeBatch" entry that opens the About window.
private struct AboutMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About SqueezeBatch") {
            openWindow(id: "about")
        }
    }
}
