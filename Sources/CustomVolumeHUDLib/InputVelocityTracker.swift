import Foundation
import QuartzCore

/// Tracks input velocity, direction, rapid tap frequency, and combos for volume adjustments.
public final class InputVelocityTracker {
    public private(set) var inputIntensity: Double = 0.0
    public private(set) var comboCount: Int = 0
    public private(set) var currentDirection: Int = 0 // +1 = up, -1 = down, 0 = neutral
    public private(set) var isKeyHeld: Bool = false
    public private(set) var lastEventTimestamp: TimeInterval = 0
    public private(set) var recentReversal: Bool = false

    private var timeSinceLastEvent: TimeInterval = 0
    private var eventTimestamps: [TimeInterval] = []
    private var lastDirection: Int = 0
    private let windowDuration: TimeInterval = 0.50 // 500 ms rolling window
    private let comboTimeout: TimeInterval = 0.35   // 350 ms between taps to keep combo
    private let holdThreshold: TimeInterval = 0.08  // events < 80 ms apart indicate key hold

    public init() {}

    /// Records a new volume event and updates velocity, intensity, and combo metrics.
    public func recordEvent(direction: Int) {
        let now = CACurrentMediaTime()

        // Clean up old events outside the 500 ms window
        eventTimestamps.removeAll { now - $0 > windowDuration }
        eventTimestamps.append(now)

        // Direction reversal detection
        if lastDirection != 0 && direction != 0 && direction != lastDirection {
            recentReversal = true
        } else {
            recentReversal = false
        }
        lastDirection = direction
        currentDirection = direction

        // Key hold detection
        if eventTimestamps.count >= 2 {
            let previous = eventTimestamps[eventTimestamps.count - 2]
            isKeyHeld = (now - previous) <= holdThreshold
        } else {
            isKeyHeld = false
        }

        // Combo calculation
        if lastEventTimestamp > 0 && timeSinceLastEvent <= comboTimeout {
            comboCount += 1
        } else {
            comboCount = 1
        }
        lastEventTimestamp = now
        timeSinceLastEvent = 0.0

        // Calculate raw input intensity based on frequency and hold state
        let count = eventTimestamps.count
        var rawIntensity: Double = 0.0

        if isKeyHeld {
            rawIntensity = 1.0
        } else {
            switch count {
            case 1:
                rawIntensity = 0.15
            case 2:
                rawIntensity = 0.35
            case 3:
                rawIntensity = 0.55
            case 4:
                rawIntensity = 0.75
            default:
                rawIntensity = min(1.0, 0.75 + Double(count - 4) * 0.08)
            }
        }

        // Add bonus intensity for combos
        if comboCount >= 7 {
            rawIntensity = min(1.0, rawIntensity + 0.15)
        }

        // Snap up to higher intensity immediately on input
        inputIntensity = max(inputIntensity, rawIntensity)
    }

    /// Ticks the decay curve over elapsed time.
    public func update(deltaTime: TimeInterval) {
        timeSinceLastEvent += deltaTime

        // Decay inputIntensity smoothly towards 0.0
        if inputIntensity > 0.0 {
            let decayRate: Double = isKeyHeld ? 1.2 : 2.0 // Decay per second
            inputIntensity = max(0.0, inputIntensity - (decayRate * deltaTime))
        }

        // Reset key held state if no event occurred within hold window
        if timeSinceLastEvent > holdThreshold * 1.5 {
            isKeyHeld = false
        }

        // Reset combo if elapsed time exceeds timeout
        if timeSinceLastEvent > comboTimeout {
            comboCount = 0
        }

        // Reset direction reversal flag after 200 ms
        if timeSinceLastEvent > 0.20 {
            recentReversal = false
        }
    }

    /// Resets all tracking state.
    public func reset() {
        inputIntensity = 0.0
        comboCount = 0
        currentDirection = 0
        lastDirection = 0
        isKeyHeld = false
        lastEventTimestamp = 0
        recentReversal = false
        eventTimestamps.removeAll()
    }

    #if DEBUG
    public func setInputIntensityForTesting(_ intensity: Double) {
        self.inputIntensity = intensity
    }
    public func setComboCountForTesting(_ count: Int) {
        self.comboCount = count
    }
    #endif
}
