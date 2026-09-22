import AppKit
import Combine
import Foundation

@MainActor
final class ImageStore: ObservableObject {
    @Published var items: [ImageItem] = []
    @Published var settings = ConversionSettings()
    @Published var isConverting = false
    @Published var completedCount = 0
    @Published var lastError: String?

    var pendingCount: Int {
        items.filter {
            if case .pending = $0.status { return true }
            if case .failed = $0.status { return true }
            return false
        }.count
    }

    var doneCount: Int { items.filter { $0.status.isDone }.count }

    var totalSavings: (saved: Int64, percent: Double?)? {
        let done = items.filter { $0.status.isDone }
        guard !done.isEmpty else { return nil }
        let before = done.reduce(0) { $0 + $1.fileSize }
        let after = done.reduce(0) { $0 + ($1.outputSize ?? 0) }
        guard before > 0 else { return nil }
        let pct = (1.0 - Double(after) / Double(before)) * 100.0
        return (before - after, pct)
    }

    // MARK: - Mutations

    func add(urls: [URL]) {
        var seen = Set(items.map { $0.sourceURL.standardizedFileURL.path })
        var expanded: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) {
                    for case let file as URL in enumerator where ImageConverter.isSupported(file) {
                        expanded.append(file)
                    }
                }
            } else if ImageConverter.isSupported(url) {
                expanded.append(url)
            }
        }
        for url in expanded {
            let key = url.standardizedFileURL.path
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            let item = ImageItem(sourceURL: url)
            item.loadThumbnail()
            items.append(item)
        }
    }

    func remove(_ item: ImageItem) {
        items.removeAll { $0.id == item.id }
    }

    func removeAll() {
        guard !isConverting else { return }
        items.removeAll()
        completedCount = 0
        lastError = nil
    }

    func removeCompleted() {
        guard !isConverting else { return }
        items.removeAll { $0.status.isDone }
    }

    func retryFailed() {
        for item in items where item.status.isFailed {
            item.status = .pending
            item.outputURL = nil
            item.outputSize = nil
        }
    }

    // MARK: - Conversion

    func convert(_ item: ImageItem) async {
        guard !isConverting else { return }
        await runConversion(for: [item])
    }

    func convertAll() async {
        let queue = items.filter {
            if case .pending = $0.status { return true }
            if case .failed = $0.status { return true }
            return false
        }
        guard !queue.isEmpty else { return }
        await runConversion(for: queue)
    }

    private func runConversion(for queue: [ImageItem]) async {
        isConverting = true
        lastError = nil
        completedCount = 0
        let settingsSnapshot = settings

        // Limit concurrency to avoid memory spikes on huge batches.
        let maxConcurrent = 4
        await withTaskGroup(of: Void.self) { group in
            var index = 0
            var active = 0

            func enqueue(_ item: ImageItem) {
                group.addTask {
                    await self.convertOne(item, settings: settingsSnapshot)
                }
            }

            while index < queue.count {
                if active < maxConcurrent {
                    enqueue(queue[index])
                    index += 1
                    active += 1
                } else {
                    await group.next()
                    active -= 1
                    completedCount = queue.count - (queue.count - index) - active
                }
            }
            while active > 0 {
                await group.next()
                active -= 1
            }
        }

        completedCount = queue.count
        isConverting = false
    }

    private func convertOne(_ item: ImageItem, settings: ConversionSettings) async {
        item.status = .converting(progress: 0.2)
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try ImageConverter.convert(sourceURL: item.sourceURL, settings: settings)
            }.value
            item.outputURL = result.0
            item.outputSize = result.1
            item.status = .done
        } catch {
            item.status = .failed(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }
}
