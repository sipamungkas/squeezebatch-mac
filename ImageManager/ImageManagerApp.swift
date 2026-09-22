import SwiftUI

@main
struct ImageManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) { EmptyView() }
        }
    }
}
