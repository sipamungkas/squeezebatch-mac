import AppKit
import SwiftUI

/// Lightweight update notifier backed by GitHub Releases.
///
/// No Sparkle / no auto-install: polls `releases/latest`, compares
/// `tag_name` (e.g. `v0.2.0`) against `CFBundleShortVersionString`,
/// and surfaces an alert / About-panel banner that opens the
/// release page in the browser. Matches the ad-hoc-signed
/// distribution in RELEASING.md (manual replace via .zip/.dmg).
@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    /// nil in tests / previews that construct their own instance.
    private let session: URLSession
    private let repository: String
    private let defaults: UserDefaults

    private let lastCheckKey = "update.lastCheck"
    private let skippedKey = "update.skippedVersion"
    private let autoCheckKey = "update.autoCheck"

    @Published var latestVersion: String?
    @Published var releaseURL: URL?
    @Published var releaseNotes: String?
    @Published var updateAvailable = false
    @Published var isChecking = false
    @Published var lastCheckFailed = false

    @Published var autoCheckEnabled: Bool {
        didSet { defaults.set(autoCheckEnabled, forKey: autoCheckKey) }
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
    }

    var lastChecked: Date? {
        defaults.object(forKey: lastCheckKey) as? Date
    }

    init(
        session: URLSession = .shared,
        repository: String = "sipamungkas/squeezebatch-mac",
        defaults: UserDefaults = .standard
    ) {
        self.session = session
        self.repository = repository
        self.defaults = defaults
        // `bool(forKey:)` is false when unset — default to true.
        let stored = defaults.object(forKey: autoCheckKey) as? Bool
        self.autoCheckEnabled = stored ?? true
    }

    /// Launch-time entry point. Throttled to once per 24h unless forced.
    func checkIfNeeded(force: Bool = false) async {
        if !force, !autoCheckEnabled { return }
        if !force, let last = lastChecked, Date().timeIntervalSince(last) < 24 * 3600 {
            return
        }
        await check()
    }

    func check() async {
        // Don't stack concurrent checks (menu spam / double .task).
        guard !isChecking else { return }
        isChecking = true
        lastCheckFailed = false
        defer { isChecking = false }

        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            return
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("SqueezeBatch/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await session.data(for: request)
            let release = try JSONDecoder().decode(Release.self, from: data)
            defaults.set(Date(), forKey: lastCheckKey)
            let latest = Self.normalizedTag(release.tag_name)
            guard Self.isNewerVersion(latest, than: currentVersion) else {
                return
            }
            // Respect "Skip this version".
            if defaults.string(forKey: skippedKey) == latest { return }
            latestVersion = latest
            releaseURL = URL(string: release.html_url)
            releaseNotes = release.body
            updateAvailable = true
        } catch {
            // Offline / rate-limited / decoding — stay silent, About shows retry.
            lastCheckFailed = true
        }
    }

    func skipVersion() {
        if let version = latestVersion {
            defaults.set(version, forKey: skippedKey)
        }
        dismiss()
    }

    func dismiss() {
        updateAvailable = false
    }

    func openReleasePage() {
        if let url = releaseURL {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Version comparison (pure, unit-tested via /tmp/version_check_test.swift)

    static func normalizedTag(_ tag: String) -> String {
        var s = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        return s
    }

    /// Numeric dot-separated compare; trailing zeros ignored (`1.0` == `1.0.0`).
    /// Pre-release suffixes (`-beta.1`) are ignored for the core compare —
    /// `/latest` never returns prereleases anyway.
    static func isNewerVersion(_ latest: String, than current: String) -> Bool {
        func parts(_ v: String) -> [Int] {
            let core = v.split(separator: "-", maxSplits: 1).first.map(String.init) ?? v
            return core.split(separator: ".").map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
        }
        let a = parts(normalizedTag(latest))
        let b = parts(normalizedTag(current))
        for i in 0 ..< max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
        let body: String?
    }
}
