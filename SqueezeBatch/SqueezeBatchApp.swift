import SwiftUI

@main
struct SqueezeBatchApp: App {
    @StateObject private var updater = AppUpdater.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(updater)
                .task {
                    await updater.checkIfNeeded()
                }
                .alert(
                    "Update available",
                    isPresented: $updater.updateAvailable,
                    presenting: updater.latestVersion
                ) { latest in
                    Button("Download v\(latest)") {
                        updater.openReleasePage()
                        updater.dismiss()
                    }
                    Button("Skip this version") {
                        updater.skipVersion()
                    }
                    Button("Later", role: .cancel) {
                        updater.dismiss()
                    }
                } message: { latest in
                    Text("SqueezeBatch v\(latest) is available — you have \(updater.currentVersion).")
                }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
                CheckForUpdatesButton()
            }
            CommandGroup(replacing: .newItem) { EmptyView() }
        }

        Window("About SqueezeBatch", id: "about") {
            AboutView()
                .environmentObject(updater)
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

/// Menu-bar "Check for Updates…" entry (Shift-Cmd-U).
private struct CheckForUpdatesButton: View {
    @ObservedObject private var updater = AppUpdater.shared

    var body: some View {
        Button("Check for Updates…") {
            Task { await updater.check() }
        }
        .keyboardShortcut("U", modifiers: [.command, .shift])
        .disabled(updater.isChecking)
    }
}
