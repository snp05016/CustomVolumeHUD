import Foundation
import QuartzCore

/// Centralized controller managing rare Brooklyn Nine-Nine Easter eggs, cooldowns, and probabilities.
public final class EasterEggController {
    public enum EasterEggType: String, CaseIterable {
        case bingpot = "BINGPOT!"
        case noDoubt = "NO DOUBT"
        case peralta = "Peralta."
        case hotDamn = "HOT DAMN!"
        case cheddar = "CHEDDAR"
        case nineNine = "NINE-NINE!"
        case terryLove = "TERRY LOVES THIS."
    }

    public private(set) var sessionChaosLevel: Double = 0.0

    // Cooldown timestamps
    private var lastTriggerTime: [EasterEggType: TimeInterval] = [:]
    private let cooldowns: [EasterEggType: TimeInterval] = [
        .bingpot: 12.0,
        .noDoubt: 15.0,
        .peralta: 8.0,
        .hotDamn: 30.0,
        .cheddar: 45.0,
        .nineNine: 18.0,
        .terryLove: 24.0
    ]

    // Base probabilities
    private let baseProbabilities: [EasterEggType: Double] = [
        .bingpot: 0.06,
        .noDoubt: 0.08,
        .peralta: 0.35, // When patience is 0
        .hotDamn: 0.02,
        .cheddar: 0.04,
        .nineNine: 0.07,
        .terryLove: 0.045
    ]

    public init() {}

    /// Registers user actions that elevate session chaos (e.g. spamming 100%, fast tapping, mute spam).
    public func registerChaosEvent(amount: Double = 0.05) {
        sessionChaosLevel = min(1.0, sessionChaosLevel + amount)
    }

    /// Ticks session chaos decay over time (slow decay over several minutes).
    public func update(deltaTime: TimeInterval) {
        if sessionChaosLevel > 0.0 {
            // Decays 1.0 over ~180 seconds (3 minutes)
            let decayRate = 1.0 / 180.0
            sessionChaosLevel = max(0.0, sessionChaosLevel - (decayRate * deltaTime))
        }
    }

    /// Evaluates whether an Easter egg is eligible to trigger.
    public func canTrigger(_ type: EasterEggType) -> Bool {
        let now = CACurrentMediaTime()
        guard let last = lastTriggerTime[type] else { return true }
        let cooldown = cooldowns[type] ?? 10.0
        return (now - last) >= cooldown
    }

    /// Attempts to trigger an Easter egg with its calculated probability.
    public func attemptTrigger(_ type: EasterEggType, probabilityMultiplier: Double = 1.0) -> Bool {
        guard canTrigger(type) else { return false }

        let base = baseProbabilities[type] ?? 0.05
        // Session chaos adds a small boost (up to +50% of base probability)
        let chaosBoost = 1.0 + (sessionChaosLevel * 0.5)
        let effectiveProbability = min(1.0, base * probabilityMultiplier * chaosBoost)

        let roll = Double.random(in: 0.0...1.0)
        if roll < effectiveProbability {
            markTriggered(type)
            return true
        }
        return false
    }

    /// Marks an Easter egg as triggered, resetting its cooldown timer.
    public func markTriggered(_ type: EasterEggType) {
        lastTriggerTime[type] = CACurrentMediaTime()
    }

    /// Force triggers an Easter egg (useful for tests and previews).
    public func forceTriggerForTesting(_ type: EasterEggType) {
        lastTriggerTime[type] = CACurrentMediaTime()
    }

    /// Resets all cooldowns and session chaos.
    public func reset() {
        lastTriggerTime.removeAll()
        sessionChaosLevel = 0.0
    }
}
