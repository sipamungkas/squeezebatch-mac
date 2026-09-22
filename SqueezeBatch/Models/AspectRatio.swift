import Foundation

/// Predefined aspect-ratio presets shared by the bulk resize controls
/// and the per-image crop editor.
enum AspectRatio: String, CaseIterable, Identifiable, Codable {
    case free
    case original
    case square      // 1:1
    case standard    // 4:3
    case portrait34  // 3:4
    case classic     // 3:2
    case portrait23  // 2:3
    case widescreen  // 16:9
    case vertical    // 9:16
    case portrait45  // 4:5
    case landscape54 // 5:4
    case ultrawide   // 21:9

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .original: return "Original"
        case .square: return "1:1"
        case .standard: return "4:3"
        case .portrait34: return "3:4"
        case .classic: return "3:2"
        case .portrait23: return "2:3"
        case .widescreen: return "16:9"
        case .vertical: return "9:16"
        case .portrait45: return "4:5"
        case .landscape54: return "5:4"
        case .ultrawide: return "21:9"
        }
    }

    /// Width / height. `nil` for `.free` (unconstrained);
    /// `.original` resolves per image at the use site.
    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .original: return nil
        case .square: return 1
        case .standard: return 4.0 / 3.0
        case .portrait34: return 3.0 / 4.0
        case .classic: return 3.0 / 2.0
        case .portrait23: return 2.0 / 3.0
        case .widescreen: return 16.0 / 9.0
        case .vertical: return 9.0 / 16.0
        case .portrait45: return 4.0 / 5.0
        case .landscape54: return 5.0 / 4.0
        case .ultrawide: return 21.0 / 9.0
        }
    }

    /// Resolve the effective ratio for a given source size.
    /// - Returns: `nil` when unconstrained (`.free`).
    func resolved(for sourceSize: CGSize) -> CGFloat? {
        switch self {
        case .free:
            return nil
        case .original:
            guard sourceSize.height > 0 else { return nil }
            return sourceSize.width / sourceSize.height
        default:
            return ratio
        }
    }
}
