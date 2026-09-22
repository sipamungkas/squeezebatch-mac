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
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(minWidth: 280)
    }
}

#Preview {
    AboutView()
}
