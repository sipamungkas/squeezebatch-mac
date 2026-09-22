import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageConverter {

    enum ConverterError: LocalizedError {
        case cannotDecode(URL)
        case cannotEncode(String)
        case cannotWrite(URL, String)

        var errorDescription: String? {
            switch self {
            case .cannotDecode(let url): return "Can't decode \(url.lastPathComponent)"
            case .cannotEncode(let m): return "Encode failed: \(m)"
            case .cannotWrite(let url, let m): return "Can't write \(url.lastPathComponent): \(m)"
            }
        }
    }

    static let supportedInputExtensions: Set<String> = [
        "png", "jpg", "jpeg", "webp", "heic", "heif", "tiff", "tif", "bmp", "gif", "jp2", "jpx"
    ]

    static func isSupported(_ url: URL) -> Bool {
        supportedInputExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Public API

    /// Convert a single image file. Returns output file URL + byte count.
    /// - Parameter cropNormalized: optional per-image crop in unit space
    ///   (origin top-left, 0...1). Applied before resizing.
    static func convert(
        sourceURL: URL,
        settings: ConversionSettings,
        outputURL: URL? = nil,
        cropNormalized: CGRect? = nil
    ) throws -> (URL, Int64) {
        guard let src = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else {
            throw ConverterError.cannotDecode(sourceURL)
        }

        let cropped = cropNormalized.map { croppedImage(cgImage, to: $0) } ?? cgImage
        let resized = resizedImage(cropped, settings: settings)
        let destURL = outputURL ?? makeOutputURL(for: sourceURL, settings: settings)
        try ensureParentExists(for: destURL)

        let metadata = copyMetadata(from: src)

        if settings.format == .webp {
            let data = try WebPCodec.encode(
                resized,
                quality: Float(settings.lossless ? 100 : settings.quality),
                lossless: settings.lossless
            )
            do {
                try data.write(to: destURL, options: .atomic)
            } catch {
                throw ConverterError.cannotWrite(destURL, error.localizedDescription)
            }
        } else {
            try writeViaImageIO(
                image: resized,
                format: settings.format,
                settings: settings,
                metadata: metadata,
                to: destURL
            )
        }

        let size = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        return (destURL, size)
    }

    // MARK: - ImageIO path

    private static func writeViaImageIO(
        image: CGImage,
        format: OutputFormat,
        settings: ConversionSettings,
        metadata: CFDictionary?,
        to url: URL
    ) throws {
        let typeID = settings.format.utType.identifier as CFString
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, typeID, 1, nil) else {
            throw ConverterError.cannotEncode("unsupported type \(typeID)")
        }

        var props: [CFString: Any] = [:]

        switch format {
        case .jpeg, .heic:
            props[kCGImageDestinationLossyCompressionQuality] = settings.effectiveQuality
        case .webp:
            // Not used (libwebp path), kept for completeness
            props[kCGImageDestinationLossyCompressionQuality] = settings.effectiveQuality
        case .png, .tiff, .bmp:
            // PNG/TIFF lossless: nothing to set. Compression is automatic.
            break
        }

        // Merge source metadata (EXIF/TIFF/GPS) so orientation & camera info survive.
        var finalProps = props
        if let metadata, settings.format != .bmp {
            for (k, v) in (metadata as? [CFString: Any] ?? [:]) {
                if finalProps[k] == nil { finalProps[k] = v }
            }
        }

        CGImageDestinationAddImage(dest, image, finalProps as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw ConverterError.cannotEncode("ImageIO finalize failed for \(format.rawValue)")
        }
    }

    // MARK: - Crop

    /// Crop a CGImage to a normalized rect (origin top-left, 0...1, clamped).
    /// Returns the original image when the rect covers (nearly) everything.
    static func croppedImage(_ image: CGImage, to normalized: CGRect) -> CGImage {
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        let clamped = normalized.intersection(unit)
        guard clamped.width >= 0.001, clamped.height >= 0.001,
              clamped.width < 0.9999 || clamped.height < 0.9999
        else { return image }

        let w = CGFloat(image.width), h = CGFloat(image.height)
        // CGImage pixel space has its origin at the top-left for cropping(to:).
        let pixelRect = CGRect(
            x: floor(clamped.minX * w),
            y: floor(clamped.minY * h),
            width: floor(clamped.width * w),
            height: floor(clamped.height * h)
        ).intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard pixelRect.width >= 1, pixelRect.height >= 1,
              let cut = image.cropping(to: pixelRect)
        else { return image }
        return cut
    }

    /// Save a cropped copy of a single image in its *source* format —
    /// the "just crop this one photo" path that skips the batch pipeline.
    /// Returns output file URL + byte count.
    static func saveCroppedCopy(
        sourceURL: URL,
        normalized: CGRect,
        outputURL: URL? = nil
    ) throws -> (URL, Int64) {
        guard let src = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else {
            throw ConverterError.cannotDecode(sourceURL)
        }

        let cropped = croppedImage(cgImage, to: normalized)
        var destURL = outputURL ?? croppedCopyURL(for: sourceURL)
        try ensureParentExists(for: destURL)
        let metadata = copyMetadata(from: src)

        let ext = sourceURL.pathExtension.lowercased()
        // GIF and JPEG-2000 have no ImageIO encode path here — fall back to PNG content.
        if ["gif", "jp2", "jpx"].contains(ext), outputURL == nil {
            let folder = sourceURL.deletingLastPathComponent()
            let stem = sourceURL.deletingPathExtension().lastPathComponent
            destURL = folder.appendingPathComponent("\(stem)-cropped.png")
            var i = 1
            while FileManager.default.fileExists(atPath: destURL.path) {
                i += 1
                destURL = folder.appendingPathComponent("\(stem)-cropped-\(i).png")
                if i > 999 { break }
            }
        }
        if ext == "webp" {
            let data = try WebPCodec.encode(cropped, quality: 100, lossless: true)
            do {
                try data.write(to: destURL, options: .atomic)
            } catch {
                throw ConverterError.cannotWrite(destURL, error.localizedDescription)
            }
        } else {
            let format: OutputFormat = {
                switch ext {
                case "jpg", "jpeg": return .jpeg
                case "tif", "tiff": return .tiff
                case "heif", "heic": return .heic
                case "png": return .png
                case "bmp": return .bmp
                default: return .png
                }
            }()
            // Crop-only: keep quality at max so the operation is (near-)lossless.
            let singleSettings = ConversionSettings(format: format, quality: 100)
            try writeViaImageIO(
                image: cropped,
                format: format,
                settings: singleSettings,
                metadata: metadata,
                to: destURL
            )
        }

        let size = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        return (destURL, size)
    }

    /// "<stem>-cropped.<ext>" next to the source, auto-numbered on collision.
    static func croppedCopyURL(for source: URL) -> URL {
        let folder = source.deletingLastPathComponent()
        let stem = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension
        var candidate = folder.appendingPathComponent("\(stem)-cropped.\(ext)")
        var i = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            i += 1
            candidate = folder.appendingPathComponent("\(stem)-cropped-\(i).\(ext)")
            if i > 999 { break }
        }
        return candidate
    }

    // MARK: - Helpers

    private static func copyMetadata(from src: CGImageSource) -> CFDictionary? {
        CGImageSourceCopyPropertiesAtIndex(src, 0, nil)
    }

    static func makeOutputURL(for source: URL, settings: ConversionSettings) -> URL {
        let baseFolder: URL
        switch settings.destination {
        case .sameFolder:
            baseFolder = source.deletingLastPathComponent()
        case .custom:
            baseFolder = settings.customFolder ?? source.deletingLastPathComponent()
        }

        let stem = source.deletingPathExtension().lastPathComponent
        let ext = settings.format.fileExtension
        var candidate = baseFolder.appendingPathComponent("\(stem).\(ext)")

        // Avoid clobbering the source when converting to the same extension,
        // or overwriting an existing file unless explicitly allowed.
        if !settings.overwriteExisting {
            if candidate.path == source.path {
                candidate = baseFolder.appendingPathComponent("\(stem)-converted.\(ext)")
            }
            var i = 1
            while FileManager.default.fileExists(atPath: candidate.path) {
                i += 1
                candidate = baseFolder.appendingPathComponent("\(stem)-\(i).\(ext)")
                if i > 999 { break }
            }
        }
        return candidate
    }

    private static func ensureParentExists(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private static func resizedImage(_ image: CGImage, settings: ConversionSettings) -> CGImage {
        let target: CGSize? = {
            switch settings.resizeMode {
            case .none:
                return nil
            case .maxDimension:
                let maxSide = CGFloat(max(settings.maxDimension, 16))
                let w = CGFloat(image.width), h = CGFloat(image.height)
                let longest = max(w, h)
                guard longest > maxSide else { return nil }
                let scale = maxSide / longest
                return CGSize(width: floor(w * scale), height: floor(h * scale))
            case .percentage:
                let pct = min(max(settings.scalePercent, 1), 1000) / 100.0
                guard pct != 1.0 else { return nil }
                return CGSize(width: floor(CGFloat(image.width) * pct), height: floor(CGFloat(image.height) * pct))
            case .exactDimensions:
                let w = floor(CGFloat(max(settings.targetWidth, 16)))
                let h = floor(CGFloat(max(settings.targetHeight, 16)))
                guard Int(w) != image.width || Int(h) != image.height else { return nil }
                return CGSize(width: w, height: h)
            }
        }()

        guard let target, target.width >= 1, target.height >= 1 else { return image }

        guard let ctx = CGContext(
            data: nil,
            width: Int(target.width),
            height: Int(target.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(origin: .zero, size: target))
        return ctx.makeImage() ?? image
    }

    // MARK: - Formatting

    static func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}
