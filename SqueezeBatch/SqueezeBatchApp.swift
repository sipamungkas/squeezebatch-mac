import SwiftUI

@main
struct SqueezeBatchApp: App {
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
