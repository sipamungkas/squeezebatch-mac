import CoreGraphics
import Foundation
import libwebp

/// Thin wrapper around libwebp C API for WebP encoding on macOS.
/// ImageIO on macOS can *decode* WebP but cannot *encode* it, so we use libwebp directly.
enum WebPCodec {

    enum CodecError: LocalizedError {
        case failedToLoadImage
        case failedToRenderRGBA
        case encodeFailed

        var errorDescription: String? {
            switch self {
            case .failedToLoadImage: return "Could not decode image"
            case .failedToRenderRGBA: return "Could not render pixels"
            case .encodeFailed: return "WebP encoder failed"
            }
        }
    }

    /// Encode a CGImage to WebP data.
    /// - Parameters:
    ///   - cgImage: source image
    ///   - quality: 0...100 (ignored when lossless == true)
    ///   - lossless: true for lossless WebP
    static func encode(_ cgImage: CGImage, quality: Float, lossless: Bool) throws -> Data {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { throw CodecError.failedToLoadImage }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw CodecError.failedToRenderRGBA
        }
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // libwebp expects tightly packed RGBA. Our buffer is RGBA (premultipliedLast, big-endian = RGBA order).
        var outputPtr: UnsafeMutablePointer<UInt8>?
        let encodedSize: Int = pixels.withUnsafeBufferPointer { buf -> Int in
            guard let base = buf.baseAddress else { return 0 }
            if lossless {
                return Int(WebPEncodeLosslessRGBA(base, Int32(width), Int32(height), Int32(bytesPerRow), &outputPtr))
            } else {
                return Int(WebPEncodeRGBA(base, Int32(width), Int32(height), Int32(bytesPerRow), quality, &outputPtr))
            }
        }

        guard encodedSize > 0, let out = outputPtr else {
            if let out = outputPtr { WebPFree(out) }
            throw CodecError.encodeFailed
        }
        defer { WebPFree(out) }
        return Data(bytes: out, count: encodedSize)
    }
}
