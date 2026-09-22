import AppKit
import Foundation

enum ConversionStatus: Equatable {
    case pending
    case converting(progress: Double)
    case done
    case failed(String)

    var isDone: Bool {
        if case .done = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .pending: return "Queued"
        case .converting: return "Converting…"
        case .done: return "Done"
        case .failed(let msg): return msg.isEmpty ? "Failed" : msg
        }
    }
}

final class ImageItem: Identifiable, ObservableObject {
    let id = UUID()
    let sourceURL: URL

    @Published var status: ConversionStatus = .pending
    @Published var outputURL: URL?
    @Published var outputSize: Int64?
    @Published var thumbnail: NSImage?
    /// Normalized crop rect in unit space (origin top-left, 0...1).
    /// `nil` means no crop — the full image is converted.
    @Published var cropRectNormalized: CGRect?

    let fileName: String
    let fileSize: Int64
    let dimensions: CGSize?
    let formatHint: String

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        self.fileName = sourceURL.lastPathComponent
        self.formatHint = sourceURL.pathExtension.uppercased()

        var size: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
           let s = attrs[.size] as? NSNumber {
            size = s.int64Value
        }
        self.fileSize = size
        self.dimensions = ImageItem.readDimensions(of: sourceURL)
    }

    var savingsPercent: Double? {
        guard let out = outputSize, fileSize > 0, status.isDone else { return nil }
        return (1.0 - Double(out) / Double(fileSize)) * 100.0
    }

    var hasCrop: Bool { cropRectNormalized != nil }

    /// Pixel dimensions of the cropped area, if a crop is set.
    func croppedDimensions() -> CGSize? {
        guard let crop = cropRectNormalized, let dims = dimensions else { return nil }
        return CGSize(width: floor(dims.width * crop.width), height: floor(dims.height * crop.height))
    }

    func clearCrop() {
        cropRectNormalized = nil
    }

    static func readDimensions(of url: URL) -> CGSize? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let h = props[kCGImagePropertyPixelHeight] as? CGFloat
        else { return nil }
        return CGSize(width: w, height: h)
    }

    func loadThumbnail() {
        if thumbnail != nil { return }
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(contentsOf: sourceURL)
        image?.isTemplate = false
        if let img = image {
            img.size = size
            DispatchQueue.main.async { self.thumbnail = img }
        } else {
            // Fallback: generate via CGImageSource thumbnail
            DispatchQueue.global(qos: .userInitiated).async {
                let options: CFDictionary = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCache: false,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 128
                ] as CFDictionary
                if let src = CGImageSourceCreateWithURL(self.sourceURL as CFURL, nil),
                   let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options) {
                    let ns = NSImage(cgImage: cg, size: size)
                    DispatchQueue.main.async { self.thumbnail = ns }
                }
            }
        }
    }
}
