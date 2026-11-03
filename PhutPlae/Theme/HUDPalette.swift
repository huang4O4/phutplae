import SwiftUI

struct HUDPalette: Equatable {
    var glow: Color
    var glowSoft: Color
    var deep: Color
    var panel: Color
    var text: Color
    var muted: Color

    static let navy = Color(red: 0.012, green: 0.035, blue: 0.075)
    static let void = Color(red: 0.004, green: 0.012, blue: 0.03)

    static func forEmotion(_ emotion: Emotion, intensity: Double) -> HUDPalette {
        let i = intensity
        let glow: Color
        switch emotion {
        case .neutral:
            glow = Color(red: 0.22, green: 0.94, blue: 1.0)
        case .angry:
            glow = Color(red: 1.0, green: 0.18 + 0.12 * (1 - i), blue: 0.14)
        case .happy:
            glow = Color(red: 1.0, green: 0.82, blue: 0.28)
        case .sad:
            glow = Color(red: 0.28, green: 0.48, blue: 1.0)
        case .fearful:
            glow = Color(red: 0.72, green: 0.38, blue: 1.0)
        case .surprised:
            glow = Color(red: 1.0, green: 0.42, blue: 0.86)
        }
        return HUDPalette(
            glow: glow,
            glowSoft: glow.opacity(0.55),
            deep: navy,
            panel: Color.white.opacity(0.04),
            text: Color(red: 0.86, green: 0.97, blue: 1.0),
            muted: glow.opacity(0.62)
        )
    }
}

extension Emotion {
    var hudCode: String {
        switch self {
        case .neutral: return "NEUTRAL"
        case .angry: return "ANGRY"
        case .happy: return "HAPPY"
        case .sad: return "SAD"
        case .fearful: return "FEAR"
        case .surprised: return "SURPRISE"
        }
    }
}
