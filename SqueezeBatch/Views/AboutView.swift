import SwiftUI

/// App version / identity read from the bundle so the About panel
/// always matches CFBundleShortVersionString (currently 0.1.0).
enum AppInfo {
    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "SqueezeBatch"
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "1"
    }

    static var versionLabel: String {
        "Version \(version) (\(build))"
    }

    static var authorURL: URL {
        URL(string: "https://sipamungkas.com")!
    }
}

struct AboutView: View {
    @EnvironmentObject private var updater: AppUpdater

    var body: some View {
        VStack(spacing: 8) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Text(AppInfo.name)
                .font(.title3.bold())

            Text(AppInfo.versionLabel)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .textSelection(.enabled)

            // "by sipamungkas" — only the name is clickable.
            HStack(spacing: 4) {
                Text("by")
                    .foregroundStyle(.secondary)
                Link("sipamungkas", destination: AppInfo.authorURL)
            }
            .font(.callout)

            Text("Drop folders. Get smaller images.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

            Divider()
                .padding(.vertical, 4)

            updateSection
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(minWidth: 300)
    }

    @ViewBuilder
    private var updateSection: some View {
        if updater.updateAvailable, let latest = updater.latestVersion {
            VStack(spacing: 6) {
                Text("Version \(latest) is available")
                    .font(.callout.bold())
                Button("Download v\(latest)") {
                    updater.openReleasePage()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button("Skip this version", role: .cancel) {
                    updater.skipVersion()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        } else {
            VStack(spacing: 6) {
                Button {
                    Task { await updater.check() }
                } label: {
                    if updater.isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("Check for Updates…")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(updater.isChecking)

                if updater.lastCheckFailed {
                    Text("Couldn’t reach GitHub — check your connection and try again.")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if let last = updater.lastChecked {
                    Text("Last checked \(last, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Toggle("Check automatically", isOn: $updater.autoCheckEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .labeled("Check automatically")
            }
        }
    }
}

private extension View {
    /// Labeled toggle without the default full-width label layout.
    func labeled(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            self
        }
    }
}

#Preview {
    AboutView()
        .environmentObject(AppUpdater.shared)
}
