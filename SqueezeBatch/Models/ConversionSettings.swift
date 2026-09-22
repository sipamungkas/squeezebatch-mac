import Foundation
import UniformTypeIdentifiers

enum OutputFormat: String, CaseIterable, Identifiable, Codable {
    case png
    case jpeg = "jpg"
    case webp
    case heic
    case tiff
    case bmp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .webp: return "WebP"
        case .heic: return "HEIC"
        case .tiff: return "TIFF"
        case .bmp: return "BMP"
        }
    }

    var fileExtension: String { rawValue }

    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .webp:
            if #available(macOS 11.0, *) { return .webP }
            return UTType(filenameExtension: "webp") ?? .data
        case .heic:
            if #available(macOS 11.0, *) { return .heic }
            return UTType(filenameExtension: "heic") ?? .data
        case .tiff: return .tiff
        case .bmp: return .bmp
        }
    }

    /// Whether this format supports a lossless mode in our converter.
    var supportsLossless: Bool {
        switch self {
        case .png, .webp, .tiff, .bmp: return true
        case .jpeg, .heic: return false
        }
    }

    /// Whether quality slider applies (lossy path).
    var usesQuality: Bool {
        switch self {
        case .jpeg, .heic, .webp: return true
        case .png, .tiff, .bmp: return false
        }
    }

    var description: String {
        switch self {
        case .png: return "Lossless, large files. Best for UI, screenshots."
        case .jpeg: return "Lossy, small files. Best for photos."
        case .webp: return "Modern web format. ~30% smaller than JPEG/PNG."
        case .heic: return "Apple format. Great quality/size for photos."
        case .tiff: return "Archival quality. Very large files."
        case .bmp: return "Uncompressed. Max compatibility."
        }
    }
}

enum OutputDestination: String, CaseIterable, Identifiable, Codable {
    case sameFolder
    case custom

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .sameFolder: return "Same as source"
        case .custom: return "Custom folder…"
        }
    }
}

enum ResizeMode: String, CaseIterable, Identifiable, Codable {
    case none
    case maxDimension
    case percentage
    case exactDimensions

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: return "No resize"
        case .maxDimension: return "Max dimension"
        case .percentage: return "Scale %"
        case .exactDimensions: return "Exact size"
        }
    }
}

struct ConversionSettings: Codable, Equatable {
    var format: OutputFormat = .webp
    var quality: Double = 80 // 1...100
    var lossless: Bool = false
    var resizeMode: ResizeMode = .none
    var maxDimension: Double = 2048
    var scalePercent: Double = 100
    var targetWidth: Double = 1920
    var targetHeight: Double = 1080
    /// Aspect preset constraining the exact-size fields (and offered in the crop editor).
    var resizeAspect: AspectRatio = .free
    var destination: OutputDestination = .sameFolder
    var customFolder: URL? = nil
    var overwriteExisting: Bool = false

    var effectiveQuality: CGFloat {
        CGFloat(min(max(quality, 1), 100) / 100.0)
    }
}
