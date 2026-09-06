import Foundation
import SwiftUI
import QuartzCore

/// ViewModel controlling Brooklyn Nine-Nine HUD state, character reactions,
/// and the directional interruptible COOL animation engine.
@MainActor
public final class VolumeHUDViewModel: ObservableObject {
    public nonisolated static let maxSlots = 10

    @Published public private(set) var volume: Float = 0.0
    @Published public private(set) var isMuted: Bool = false
    @Published public private(set) var displayedCount: Int = 0
    @Published public private(set) var slotBounces: [CGFloat] = Array(repeating: 0, count: maxSlots)
    @Published public private(set) var slotOpacities: [Double] = Array(repeating: 0.0, count: maxSlots)
    @Published public private(set) var jakeBounceY: CGFloat = 0
    @Published public private(set) var jakeSpeech: String? = nil
    @Published public private(set) var holtSpeech: String? = nil
    @Published public private(set) var holtEyebrowRaised: Bool = false

    private var activeAnimationId: UUID = UUID()
    private var lastUpdateTime: TimeInterval = 0
    private var pendingWorkItems: [DispatchWorkItem] = []

    public init(volume: Float = 0.0, isMuted: Bool = false) {
        self.volume = max(0.0, min(1.0, volume))
        self.isMuted = isMuted
        let initialSlots = isMuted ? 0 : Self.calculateSlotCount(for: volume)
        self.displayedCount = initialSlots
        for i in 0..<Self.maxSlots {
            self.slotOpacities[i] = i < initialSlots ? 1.0 : 0.0
        }
    }

    /// Converts volume 0.0...1.0 to 0...10 discrete slots.
    public nonisolated static func calculateSlotCount(for volume: Float) -> Int {
        let clamped = max(0.0, min(1.0, volume))
        return min(maxSlots, max(0, Int(round(clamped * Float(maxSlots)))))
    }

    public var targetSlotCount: Int {
        if isMuted { return 0 }
        return Self.calculateSlotCount(for: volume)
    }

    /// Updates the HUD volume and mute states.
    public func update(volume: Float, isMuted: Bool, animated: Bool = true) {
        let newVolume = max(0.0, min(1.0, volume))
        let wasMuted = self.isMuted
        let oldDisplayed = self.displayedCount

        self.volume = newVolume
        self.isMuted = isMuted

        let target = self.targetSlotCount

        // Cancel previous in-flight animations
        cancelPendingAnimations()
        let animId = UUID()
        self.activeAnimationId = animId

        let now = CACurrentMediaTime()
        let timeSinceLast = now - lastUpdateTime
        lastUpdateTime = now
        let isRapidTapping = timeSinceLast < 0.20

        if !animated {
            applyImmediateState(targetCount: target)
            return
        }

        // Case 1: Muted
        if isMuted {
            // Clear all COOLs immediately
            self.displayedCount = 0
            for i in 0..<Self.maxSlots {
                self.slotOpacities[i] = 0.0
                self.slotBounces[i] = 0.0
            }
            self.jakeBounceY = 0
            self.jakeSpeech = nil
            self.holtEyebrowRaised = false
            self.holtSpeech = nil

            // After ~300 ms, Holt displays subtle silence reaction
            let muteReactionItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.activeAnimationId == animId, self.isMuted else { return }
                let reactions = ["Silence.", "Finally."]
                self.holtSpeech = reactions.randomElement()
            }
            pendingWorkItems.append(muteReactionItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: muteReactionItem)
            return
        }

        // Case 2: Unmuting (was muted, now active)
        if wasMuted && !isMuted {
            self.holtSpeech = nil
            self.holtEyebrowRaised = false

            if target == 0 {
                self.displayedCount = 0
                return
            }

            // Rapidly rebuild sequence back to active volume within 250-400 ms
            let rebuildDuration: Double = 0.30
            let stepDelay = rebuildDuration / Double(target)

            for i in 0..<target {
                let delay = Double(i) * stepDelay
                let item = DispatchWorkItem { [weak self] in
                    guard let self = self, self.activeAnimationId == animId else { return }
                    self.displayedCount = i + 1
                    self.slotOpacities[i] = 1.0
                    self.slotBounces[i] = -1.5

                    let resetBounceItem = DispatchWorkItem { [weak self] in
                        guard let self = self, self.activeAnimationId == animId else { return }
                        self.slotBounces[i] = 0.0
                    }
                    self.pendingWorkItems.append(resetBounceItem)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: resetBounceItem)

                    if i + 1 == target && target >= 9 {
                        self.triggerJakeCelebration(atMax: target == 10)
                        if target == 10 {
                            self.triggerMaxVolumeEasterEggs()
                        }
                    }
                }
                pendingWorkItems.append(item)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            }
            return
        }

        // Case 3: Increasing volume (Left-to-right sequential reveal from Jake to Holt)
        if target > oldDisplayed {
            self.holtSpeech = nil

            let stepCount = target - oldDisplayed
            // Micro-delay: 40-80 ms normally; accelerate down to ~15-30 ms on rapid tapping to finish in < 150 ms
            let stepDelay: Double = isRapidTapping
                ? min(0.030, max(0.015, 0.100 / Double(stepCount)))
                : 0.055

            for i in oldDisplayed..<target {
                let stepOffset = i - oldDisplayed
                let delay = Double(stepOffset) * stepDelay

                let revealItem = DispatchWorkItem { [weak self] in
                    guard let self = self, self.activeAnimationId == animId else { return }
                    self.displayedCount = i + 1
                    self.slotOpacities[i] = 1.0
                    self.slotBounces[i] = -2.0 // 2px bounce

                    let bounceResetItem = DispatchWorkItem { [weak self] in
                        guard let self = self, self.activeAnimationId == animId else { return }
                        self.slotBounces[i] = 0.0
                    }
                    self.pendingWorkItems.append(bounceResetItem)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.07, execute: bounceResetItem)
                }
                pendingWorkItems.append(revealItem)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: revealItem)
            }

            // Character Personality: Jake becomes increasingly energetic near 100%
            if target >= 9 {
                triggerJakeCelebration(atMax: target == 10)
            } else if target >= 7 {
                self.jakeBounceY = -2.0
                let reset = DispatchWorkItem { [weak self] in self?.jakeBounceY = 0 }
                pendingWorkItems.append(reset)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10, execute: reset)
            }

            // 100% Easter eggs
            if target == 10 {
                triggerMaxVolumeEasterEggs()
            } else {
                self.holtEyebrowRaised = false
                self.jakeSpeech = nil
            }
            return
        }

        // Case 4: Decreasing volume (Rapid flicker/dissolve right-to-left)
        if target < oldDisplayed {
            self.holtSpeech = nil
            self.holtEyebrowRaised = false
            if target < 10 {
                self.jakeSpeech = nil
            }

            let slotsToRemove = oldDisplayed - target
            let flickerDuration: Double = 0.020
            let stepDelay: Double = min(0.035, max(0.015, 0.080 / Double(slotsToRemove)))

            for i in stride(from: oldDisplayed - 1, through: target, by: -1) {
                let stepOffset = (oldDisplayed - 1) - i
                let startTime = Double(stepOffset) * stepDelay

                // Rapid phosphor flicker right before extinguishing
                let flickerItem = DispatchWorkItem { [weak self] in
                    guard let self = self, self.activeAnimationId == animId else { return }
                    self.slotOpacities[i] = 0.35
                }
                pendingWorkItems.append(flickerItem)
                DispatchQueue.main.asyncAfter(deadline: .now() + startTime, execute: flickerItem)

                let dissolveItem = DispatchWorkItem { [weak self] in
                    guard let self = self, self.activeAnimationId == animId else { return }
                    self.displayedCount = i
                    self.slotOpacities[i] = 0.0
                    self.slotBounces[i] = 0.0
                }
                pendingWorkItems.append(dissolveItem)
                DispatchQueue.main.asyncAfter(deadline: .now() + startTime + flickerDuration, execute: dissolveItem)
            }
            return
        }

        // Case 5: Volume unchanged
        if target == 10 {
            triggerJakeCelebration(atMax: true)
            triggerMaxVolumeEasterEggs()
        }
    }

    private func applyImmediateState(targetCount: Int) {
        self.displayedCount = targetCount
        for i in 0..<Self.maxSlots {
            self.slotOpacities[i] = i < targetCount ? 1.0 : 0.0
            self.slotBounces[i] = 0.0
        }
        if isMuted {
            self.holtSpeech = "Silence."
            self.jakeSpeech = nil
            self.holtEyebrowRaised = false
        } else {
            self.holtSpeech = nil
            if targetCount == 10 {
                triggerMaxVolumeEasterEggs()
                triggerJakeCelebration(atMax: true)
            } else {
                self.jakeSpeech = nil
                self.holtEyebrowRaised = false
            }
        }
    }

    private func triggerJakeCelebration(atMax: Bool) {
        let bounceAmount: CGFloat = atMax ? -5.0 : -3.0
        self.jakeBounceY = bounceAmount

        let returnItem = DispatchWorkItem { [weak self] in
            self?.jakeBounceY = 1.0
            let finalItem = DispatchWorkItem { [weak self] in
                self?.jakeBounceY = 0.0
            }
            self?.pendingWorkItems.append(finalItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: finalItem)
        }
        pendingWorkItems.append(returnItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10, execute: returnItem)
    }

    private func triggerMaxVolumeEasterEggs() {
        // Jake Easter egg
        let jakeOptions = ["BINGPOT!", "NO DOUBT!", "COOL COOL COOL!"]
        self.jakeSpeech = jakeOptions.randomElement()

        // Holt subtle Easter egg: eyebrow shift or "Peralta."
        let roll = Double.random(in: 0...1)
        if roll < 0.40 {
            self.holtEyebrowRaised = true
            self.holtSpeech = nil
        } else if roll < 0.70 {
            self.holtEyebrowRaised = false
            self.holtSpeech = "Peralta."
        } else {
            self.holtEyebrowRaised = false
            self.holtSpeech = nil
        }
    }

    private func cancelPendingAnimations() {
        for item in pendingWorkItems {
            item.cancel()
        }
        pendingWorkItems.removeAll()

        // Clean up any in-flight bounce or flicker states so nothing is left stuck
        for i in 0..<Self.maxSlots {
            self.slotBounces[i] = 0.0
            if i < displayedCount {
                self.slotOpacities[i] = 1.0
            } else {
                self.slotOpacities[i] = 0.0
            }
        }
        self.jakeBounceY = 0.0
    }

    #if DEBUG
    public func setJakeSpeechForTesting(_ text: String?) {
        self.jakeSpeech = text
    }

    public func setHoltSpeechForTesting(_ text: String?) {
        self.holtSpeech = text
    }
    #endif
}
