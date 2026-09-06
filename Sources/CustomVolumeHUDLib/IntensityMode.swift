import Foundation

/// Defines animation intensity presets for the Brooklyn Nine-Nine volume HUD.
public enum IntensityMode: String, CaseIterable, Sendable {
    case professional = "Professional"
    case noice = "Noice"
    case fullPeralta = "Full Peralta"

    /// Multiplier for Jake's bounce and lean animations.
    public var jakeMotionMultiplier: CGFloat {
        switch self {
        case .professional: return 0.4
        case .noice: return 1.0
        case .fullPeralta: return 1.4
        }
    }

    /// Multiplier for COOL travel velocities.
    public var coolSpeedMultiplier: Double {
        switch self {
        case .professional: return 1.3
        case .noice: return 1.0
        case .fullPeralta: return 1.15
        }
    }

    /// Multiplier for Easter egg probabilities.
    public var easterEggMultiplier: Double {
        switch self {
        case .professional: return 0.25
        case .noice: return 1.0
        case .fullPeralta: return 1.75
        }
    }

    /// Max allowable overflow COOLs stacking near Holt.
    public var maxOverflowSlots: Int {
        switch self {
        case .professional: return 1
        case .noice: return 3
        case .fullPeralta: return 5
        }
    }
}
