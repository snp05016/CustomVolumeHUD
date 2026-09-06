import Foundation
import SwiftUI
import QuartzCore

/// ViewModel controlling the continuous, momentum-aware Brooklyn Nine-Nine HUD animation engine.
@MainActor
public final class VolumeHUDViewModel: ObservableObject {
    public nonisolated static let maxSlots = 10
    public nonisolated static let maxOverflowSlots = 5

    // Primary State
    @Published public private(set) var volume: Float = 0.0
    @Published public private(set) var isMuted: Bool = false
    @Published public private(set) var displayedCount: Int = 0
    @Published public private(set) var session: HUDSession?
    @Published public private(set) var runToTerryState = RunToTerryRenderState()
    @Published public private(set) var hudPulseScale: CGFloat = 1.0

    // Physical COOL Slot Arrays (10 slots)
    @Published public private(set) var slotBounces: [CGFloat] = Array(repeating: 0, count: maxSlots)
    @Published public private(set) var slotOpacities: [Double] = Array(repeating: 0.0, count: maxSlots)
    @Published public private(set) var slotOffsetsX: [CGFloat] = Array(repeating: 0, count: maxSlots)
    @Published public private(set) var slotScales: [CGFloat] = Array(repeating: 1.0, count: maxSlots)

    // 100% Overflow COOL Slots (stacking near Holt)
    @Published public private(set) var overflowCoolCount: Int = 0
    @Published public private(set) var overflowOffsetsX: [CGFloat] = Array(repeating: 0, count: maxOverflowSlots)
    @Published public private(set) var overflowJiggleY: [CGFloat] = Array(repeating: 0, count: maxOverflowSlots)

    // Continuous Velocity & Character States
    @Published public private(set) var inputIntensity: Double = 0.0
    @Published public private(set) var comboCount: Int = 0
    @Published public private(set) var jakeExcitement: Double = 0.0
    @Published public private(set) var jakeBounceY: CGFloat = 0.0
    @Published public private(set) var jakeLeanX: CGFloat = 0.0
    @Published public private(set) var jakeSpeech: String? = nil

    @Published public private(set) var holtPatience: Double = 1.0
    @Published public private(set) var holtEyeShift: CGFloat = 0.0
    @Published public private(set) var holtEyebrowRaised: Bool = false
    @Published public private(set) var holtSpeech: String? = nil

    // Rare Cheddar Cameo State
    @Published public private(set) var cheddarActive: Bool = false
    @Published public private(set) var cheddarPositionX: CGFloat = -40.0

    // Configuration
    @Published public var intensityMode: IntensityMode = .noice

    // Subsystems
    public let velocityTracker = InputVelocityTracker()
    public let easterEggController = EasterEggController()
    private let runToTerryEngine = RunToTerrySceneEngine()

    // Internal Loop & Pacing State
    private var activeAnimationId: UUID = UUID()
    private var displayTimer: Timer?
    private var lastTickTime: TimeInterval = 0
    private var pendingWorkItems: [DispatchWorkItem] = []
    private var lastVolumeChangeTime: TimeInterval = 0
    private var overflowResetTimer: DispatchWorkItem?

    public init(volume: Float = 0.0, isMuted: Bool = false, intensityMode: IntensityMode = .noice) {
        self.volume = max(0.0, min(1.0, volume))
        self.isMuted = isMuted
        self.intensityMode = intensityMode

        let initialSlots = isMuted ? 0 : Self.calculateSlotCount(for: volume)
        self.displayedCount = initialSlots
        for i in 0..<Self.maxSlots {
            self.slotOpacities[i] = i < initialSlots ? 1.0 : 0.0
            self.slotScales[i] = 1.0
            self.slotOffsetsX[i] = 0.0
        }
        self.jakeExcitement = Double(initialSlots) / 10.0 * 0.3
        self.holtPatience = 1.0
        runToTerryEngine.reset(volume: self.volume, isMuted: isMuted)
        self.runToTerryState = runToTerryEngine.state
    }

    deinit {
        displayTimer?.invalidate()
    }

    // MARK: - Discrete Mapping

    public nonisolated static func calculateSlotCount(for volume: Float) -> Int {
        let clamped = max(0.0, min(1.0, volume))
        return min(maxSlots, max(0, Int(round(clamped * Float(maxSlots)))))
    }

    public var targetSlotCount: Int {
        if isMuted { return 0 }
        return Self.calculateSlotCount(for: volume)
    }

    public var currentSceneMode: HUDSceneMode {
        session?.sceneMode ?? .coolHolt
    }

    // MARK: - HUD Session Lifetime

    /// Locks a scene choice until `endSession()` is called after the panel reaches zero opacity.
    public func beginSession(sceneMode: HUDSceneMode? = nil) {
        let now = CACurrentMediaTime()
        if var activeSession = session {
            activeSession.lastInputTimestamp = now
            session = activeSession
            startDisplayLoop()
            return
        }

        let selectedMode = sceneMode ?? HUDSceneMode.random()
        session = HUDSession(
            sceneMode: selectedMode,
            startTimestamp: now,
            lastInputTimestamp: now
        )
        velocityTracker.reset()
        easterEggController.reset()
        inputIntensity = 0
        comboCount = 0
        hudPulseScale = 1
        synchronizeCoolStateToCurrentVolume()
        runToTerryEngine.reset(volume: volume, isMuted: isMuted)
        runToTerryState = runToTerryEngine.state
        startDisplayLoop()
    }

    public func endSession() {
        cancelPendingAnimations()
        overflowResetTimer?.cancel()
        overflowResetTimer = nil
        stopDisplayLoop()
        session = nil
        hudPulseScale = 1
        jakeSpeech = nil
        holtSpeech = nil
        overflowCoolCount = 0
        cheddarActive = false
    }

    private func noteSessionInput() {
        guard var activeSession = session else { return }
        activeSession.lastInputTimestamp = CACurrentMediaTime()
        session = activeSession
    }

    private func synchronizeCoolStateToCurrentVolume() {
        let count = isMuted ? 0 : Self.calculateSlotCount(for: volume)
        displayedCount = count
        for index in 0..<Self.maxSlots {
            slotOpacities[index] = index < count ? 1 : 0
            slotBounces[index] = 0
            slotOffsetsX[index] = 0
            slotScales[index] = index < count ? 1 : 0.85
        }
        overflowCoolCount = 0
        holtEyebrowRaised = false
        jakeSpeech = nil
        holtSpeech = nil
    }

    // MARK: - Continuous Display Loop (120Hz-capable, elapsed-time driven)

    private func startDisplayLoop() {
        guard displayTimer == nil else { return }
        lastTickTime = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func stopDisplayLoop() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    public func tick(explicitDeltaTime: TimeInterval? = nil) {
        let now = CACurrentMediaTime()
        let dt = explicitDeltaTime ?? max(0.001, min(0.1, now - lastTickTime))
        lastTickTime = now

        // 1. Update Input Velocity & Intensity
        velocityTracker.update(deltaTime: dt)
        self.inputIntensity = velocityTracker.inputIntensity
        self.comboCount = velocityTracker.comboCount

        // 2. Update Session Chaos
        easterEggController.update(deltaTime: dt)

        if currentSceneMode == .runToTerry {
            runToTerryEngine.tick(deltaTime: dt, inputIntensity: inputIntensity)
            let nextState = runToTerryEngine.state
            if nextState != runToTerryState {
                runToTerryState = nextState
            }
        }

        if hudPulseScale != 1 {
            let factor = CGFloat(1.0 - exp(-18.0 * dt))
            hudPulseScale += (1 - hudPulseScale) * factor
            if abs(hudPulseScale - 1) < 0.001 {
                hudPulseScale = 1
            }
        }

        // 3. Smooth Jake Excitement Interpolation
        let baseVolumeExcitement = Double(targetSlotCount) / 10.0
        let targetExcitement = min(1.0, (baseVolumeExcitement * 0.5) + (inputIntensity * 0.5))
        if jakeExcitement < targetExcitement {
            jakeExcitement = min(targetExcitement, jakeExcitement + (3.0 * dt))
        } else {
            jakeExcitement = max(targetExcitement, jakeExcitement - (1.2 * dt))
        }

        // Jake Lean scales with excitement (0 to 2 px forward lean)
        let leanTarget = CGFloat(jakeExcitement * 2.5) * intensityMode.jakeMotionMultiplier
        jakeLeanX = round(jakeLeanX + (leanTarget - jakeLeanX) * min(1.0, CGFloat(10.0 * dt)))

        // 4. Smooth Holt Patience Recovery
        if holtPatience < 1.0 {
            // Recovers back to 1.0 over ~20 seconds
            holtPatience = min(1.0, holtPatience + (0.05 * dt))
        }

        // Update Holt Micro-reactions based on patience
        if holtPatience < 0.25 {
            holtEyeShift = -1.5 // Shift pupils towards Jake
        } else if holtPatience < 0.55 {
            holtEyeShift = -0.75
        } else {
            holtEyeShift = 0.0
        }

        // 5. Continuous Slot Physical Momentum (X translation, scale, bounce settle)
        for i in 0..<Self.maxSlots {
            // Settle horizontal offset towards 0.0
            if slotOffsetsX[i] != 0.0 {
                let speed: CGFloat = CGFloat(25.0 * intensityMode.coolSpeedMultiplier)
                let step = slotOffsetsX[i] * speed * CGFloat(dt)
                if abs(slotOffsetsX[i]) < 0.2 {
                    slotOffsetsX[i] = 0.0
                } else {
                    slotOffsetsX[i] -= step
                }
            }

            // Settle scale towards target (1.0 if active, 0.85 if inactive)
            let targetScale: CGFloat = (i < displayedCount && slotOpacities[i] > 0.0) ? 1.0 : 0.85
            if abs(slotScales[i] - targetScale) > 0.01 {
                slotScales[i] += (targetScale - slotScales[i]) * min(1.0, CGFloat(16.0 * dt))
            } else {
                slotScales[i] = targetScale
            }
        }

        // 6. Cheddar Cameo Animation Tick
        if cheddarActive {
            cheddarPositionX += CGFloat(180.0 * dt)
            // If Cheddar passes across slots (roughly 100 to 440 px), nudge slots slightly
            if cheddarPositionX > 600 {
                cheddarActive = false
                cheddarPositionX = -40.0
            }
        }
    }

    // MARK: - Authoritative Volume Update

    public func update(
        volume: Float,
        isMuted: Bool,
        animated: Bool = true,
        inputAction: HUDInputAction = .inferred
    ) {
        let newVolume = max(0.0, min(1.0, volume))
        let oldVolume = self.volume
        let wasMuted = self.isMuted
        let oldDisplayed = self.displayedCount
        self.volume = newVolume
        self.isMuted = isMuted

        let target = self.targetSlotCount
        let inferredDirection = newVolume > oldVolume ? 1 : (newVolume < oldVolume ? -1 : 0)
        let direction = inputAction.explicitDirection ?? inferredDirection
        let isRepeatedMaxPress = newVolume >= 0.999 && oldVolume >= 0.999 &&
            (inputAction == .volumeUp || inputAction == .inferred)
        let isRepeatedMinPress = newVolume <= 0.001 && oldVolume <= 0.001 &&
            (inputAction == .volumeDown || inputAction == .inferred)

        // Record velocity event
        velocityTracker.recordEvent(direction: direction)
        self.inputIntensity = velocityTracker.inputIntensity
        self.comboCount = velocityTracker.comboCount
        noteSessionInput()

        if isRepeatedMaxPress || isRepeatedMinPress {
            hudPulseScale = 1.024
        }

        // Cancel previous in-flight discrete tasks
        cancelPendingAnimations()
        let animId = UUID()
        self.activeAnimationId = animId

        runToTerryEngine.updateTarget(
            volume: newVolume,
            isMuted: isMuted,
            inputAction: inputAction,
            isRepeatedBoundaryPress: isRepeatedMaxPress || isRepeatedMinPress,
            intensityMode: intensityMode,
            easterEggController: easterEggController
        )

        if currentSceneMode == .runToTerry {
            if !animated {
                runToTerryEngine.snapToTarget()
            }
            runToTerryState = runToTerryEngine.state
            return
        }

        if !animated {
            applyImmediateState(targetCount: target)
            return
        }

        // CASE 1: Mute Interruption
        if isMuted {
            handleMuteInterruption(animId: animId)
            return
        }

        // CASE 2: Unmute Continuation
        if wasMuted && !isMuted {
            handleUnmuteContinuation(target: target, animId: animId)
            return
        }

        // CASE 3: 100% Volume Repeat / Overflow Interaction
        if target == 10 && oldDisplayed == 10 && isRepeatedMaxPress {
            handleMaxVolumeOverflow()
            return
        }

        // CASE 4: Volume Down while already at zero still gets a character reaction.
        if target == 0 && oldDisplayed == 0 && !isMuted && isRepeatedMinPress {
            handleMinVolumeBoundary()
            return
        }

        // CASE 5: Volume Increase (Directional reveal from Jake toward Holt)
        if target > oldDisplayed {
            handleVolumeIncrease(from: oldDisplayed, to: target, animId: animId)
            return
        }

        // CASE 6: Volume Decrease (Right-to-left dissolve with phosphor flicker)
        if target < oldDisplayed {
            handleVolumeDecrease(from: oldDisplayed, to: target, animId: animId)
            return
        }

        // CASE 7: Target unchanged
        if target == 10 {
            triggerJakeCelebration(atMax: true)
        }
    }

    // MARK: - State Handlers

    private func handleMinVolumeBoundary() {
        easterEggController.registerChaosEvent(amount: 0.05)
        jakeSpeech = comboCount >= 3 ? "STILL ZERO!" : "NO MORE COOLS!"
        holtSpeech = comboCount >= 4 ? "THAT IS ZERO, PERALTA." : nil
        holtEyebrowRaised = comboCount >= 2
        jakeBounceY = 2
        hudPulseScale = 1.024

        let animationId = activeAnimationId
        let settle = DispatchWorkItem { [weak self] in
            guard let self = self, self.activeAnimationId == animationId else { return }
            self.jakeBounceY = 0
        }
        pendingWorkItems.append(settle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10, execute: settle)
    }

    private func handleMuteInterruption(animId: UUID) {
        // Immediately clear all slots and freeze in-flight motion
        self.displayedCount = 0
        for i in 0..<Self.maxSlots {
            self.slotOpacities[i] = 0.0
            self.slotBounces[i] = 0.0
            self.slotOffsetsX[i] = 0.0
            self.slotScales[i] = 0.85
        }
        self.overflowCoolCount = 0
        self.jakeBounceY = 0.0
        self.jakeLeanX = 0.0
        self.jakeSpeech = nil
        self.holtEyebrowRaised = false
        self.holtSpeech = nil

        // Register chaos
        easterEggController.registerChaosEvent(amount: 0.04)

        // After ~300 ms, Holt displays subtle silence reaction
        let muteReactionItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.activeAnimationId == animId, self.isMuted else { return }
            let reactions = ["Silence.", "Finally."]
            self.holtSpeech = reactions.randomElement()
        }
        pendingWorkItems.append(muteReactionItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: muteReactionItem)
    }

    private func handleUnmuteContinuation(target: Int, animId: UUID) {
        self.holtSpeech = nil
        self.holtEyebrowRaised = false

        if target == 0 {
            self.displayedCount = 0
            return
        }

        // Rapidly cascade back to target within 200-350 ms regardless of slot count
        let totalDuration = 0.28
        let stepDelay = totalDuration / Double(target)

        for i in 0..<target {
            let delay = Double(i) * stepDelay
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, self.activeAnimationId == animId else { return }
                self.displayedCount = i + 1
                self.slotOpacities[i] = 1.0
                self.slotOffsetsX[i] = -4.0 // Slide in from Jake
                self.slotScales[i] = 1.0
                self.slotBounces[i] = -1.5

                let resetBounce = DispatchWorkItem { [weak self] in
                    guard let self = self, self.activeAnimationId == animId else { return }
                    self.slotBounces[i] = 0.0
                }
                self.pendingWorkItems.append(resetBounce)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: resetBounce)

                if i + 1 == target && target >= 9 {
                    self.triggerJakeCelebration(atMax: target == 10)
                }
            }
            pendingWorkItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    private func handleVolumeIncrease(from start: Int, to target: Int, animId: UUID) {
        self.holtSpeech = nil
        self.overflowCoolCount = 0

        // Reset Jake speech if below 10
        if target < 10 {
            self.jakeSpeech = nil
        }

        // Continuous pacing interval: lerp(0.085, 0.024, inputIntensity)
        let intensity = self.inputIntensity
        let baseInterval = 0.055
        let minInterval = 0.020
        let stepDelay = max(minInterval, baseInterval - (intensity * 0.035)) / intensityMode.coolSpeedMultiplier

        let stepCount = target - start
        // Fast catch-up: if backlog is large (> 4 slots), compress delay to stay responsive < 140 ms
        let effectiveStepDelay = min(stepDelay, 0.120 / Double(stepCount))

        for i in start..<target {
            let offsetIndex = i - start
            let delay = Double(offsetIndex) * effectiveStepDelay

            let revealItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.activeAnimationId == animId else { return }
                self.displayedCount = i + 1
                self.slotOpacities[i] = 1.0
                // Physical horizontal spawn trajectory: spawns 5-8 px closer to Jake
                self.slotOffsetsX[i] = -CGFloat(5.0 + (Double(self.jakeExcitement) * 3.0))
                self.slotScales[i] = 0.92
                self.slotBounces[i] = -2.0 // 2px bounce

                let bounceReset = DispatchWorkItem { [weak self] in
                    guard let self = self, self.activeAnimationId == animId else { return }
                    self.slotBounces[i] = 0.0
                }
                self.pendingWorkItems.append(bounceReset)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07, execute: bounceReset)
            }
            pendingWorkItems.append(revealItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: revealItem)
        }

        // Character dynamic excitation
        if target >= 9 {
            triggerJakeCelebration(atMax: target == 10)
        } else if target >= 6 {
            self.jakeBounceY = -CGFloat(1.5 * intensityMode.jakeMotionMultiplier)
            let reset = DispatchWorkItem { [weak self] in self?.jakeBounceY = 0 }
            pendingWorkItems.append(reset)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: reset)
        }

        // Easter eggs
        if target == 10 {
            evaluateEasterEggsOnMaxVolume()
        } else if target >= 8 && intensity > 0.65 {
            if easterEggController.attemptTrigger(.noDoubt, probabilityMultiplier: intensityMode.easterEggMultiplier) {
                self.jakeSpeech = "NO DOUBT"
            }
        }

        // Potential rare Cheddar cameo
        if easterEggController.attemptTrigger(.cheddar, probabilityMultiplier: intensityMode.easterEggMultiplier) {
            triggerCheddarCameo()
        }
    }

    private func handleVolumeDecrease(from start: Int, to target: Int, animId: UUID) {
        self.holtSpeech = nil
        self.holtEyebrowRaised = false
        self.overflowCoolCount = 0
        if target < 10 {
            self.jakeSpeech = nil
        }

        // Holt patience decreases slightly on rapid reversals
        if velocityTracker.recentReversal {
            holtPatience = max(0.0, holtPatience - 0.12)
            easterEggController.registerChaosEvent(amount: 0.06)
        }

        let slotsToRemove = start - target
        let flickerDuration: Double = 0.020
        let stepDelay: Double = min(0.035, max(0.015, 0.080 / Double(slotsToRemove)))

        for i in stride(from: start - 1, through: target, by: -1) {
            let stepOffset = (start - 1) - i
            let startTime = Double(stepOffset) * stepDelay

            // 1. Phosphor flicker & retract 3px towards Jake
            let flickerItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.activeAnimationId == animId else { return }
                self.slotOpacities[i] = 0.35
                self.slotOffsetsX[i] = -3.0
                self.slotScales[i] = 0.85
            }
            pendingWorkItems.append(flickerItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + startTime, execute: flickerItem)

            // 2. Extinguish
            let dissolveItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.activeAnimationId == animId else { return }
                self.displayedCount = i
                self.slotOpacities[i] = 0.0
                self.slotBounces[i] = 0.0
                self.slotOffsetsX[i] = 0.0
            }
            pendingWorkItems.append(dissolveItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + startTime + flickerDuration, execute: dissolveItem)
        }
    }

    // MARK: - 100% Volume Overflow Stacking

    private func handleMaxVolumeOverflow() {
        let maxSlots = intensityMode.maxOverflowSlots
        overflowCoolCount = min(maxSlots, overflowCoolCount + 1)

        // Drop Holt's patience with each extra 100% hit
        holtPatience = max(0.0, holtPatience - 0.22)
        easterEggController.registerChaosEvent(amount: 0.08)

        // Jake celebrates with micro-bounce and speech
        triggerJakeCelebration(atMax: true)
        evaluateEasterEggsOnMaxVolume()

        // Jiggle overflow slots
        for idx in 0..<overflowCoolCount {
            overflowJiggleY[idx] = CGFloat.random(in: -2.0...2.0)
            overflowOffsetsX[idx] = CGFloat(idx * 8)
        }

        // Holt reaction progression
        if holtPatience <= 0.05 {
            if easterEggController.attemptTrigger(.peralta, probabilityMultiplier: intensityMode.easterEggMultiplier) {
                self.holtSpeech = "Peralta."
                self.holtEyebrowRaised = false
            } else {
                self.holtEyebrowRaised = true
            }
        } else if holtPatience < 0.40 {
            self.holtEyebrowRaised = true
            self.holtSpeech = nil
        }

        // Auto-collapse overflow COOLs after 1.2s of inactivity
        overflowResetTimer?.cancel()
        let resetItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeOut(duration: 0.20)) {
                self.overflowCoolCount = 0
                for k in 0..<Self.maxOverflowSlots {
                    self.overflowJiggleY[k] = 0.0
                    self.overflowOffsetsX[k] = 0.0
                }
            }
        }
        self.overflowResetTimer = resetItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: resetItem)
    }

    // MARK: - Micro-Animations & Easter Eggs

    private func triggerJakeCelebration(atMax: Bool) {
        let bounceAmount: CGFloat = (atMax ? -4.5 : -2.5) * intensityMode.jakeMotionMultiplier
        self.jakeBounceY = bounceAmount

        let returnItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.jakeBounceY = 1.0
            let finalItem = DispatchWorkItem { [weak self] in
                self?.jakeBounceY = 0.0
            }
            self.pendingWorkItems.append(finalItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: finalItem)
        }
        pendingWorkItems.append(returnItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10, execute: returnItem)
    }

    private func evaluateEasterEggsOnMaxVolume() {
        if easterEggController.attemptTrigger(.bingpot, probabilityMultiplier: intensityMode.easterEggMultiplier) {
            self.jakeSpeech = "BINGPOT!"
        } else if easterEggController.attemptTrigger(.noDoubt, probabilityMultiplier: intensityMode.easterEggMultiplier) {
            self.jakeSpeech = "NO DOUBT!"
        } else {
            self.jakeSpeech = "COOL COOL COOL!"
        }

        // Holt subtle reaction
        let roll = Double.random(in: 0...1)
        if roll < 0.40 {
            self.holtEyebrowRaised = true
            self.holtSpeech = nil
        } else if roll < 0.65 && holtPatience < 0.5 {
            self.holtEyebrowRaised = false
            self.holtSpeech = "Peralta."
        } else {
            self.holtEyebrowRaised = false
            self.holtSpeech = nil
        }
    }

    private func triggerCheddarCameo() {
        guard !cheddarActive else { return }
        cheddarActive = true
        cheddarPositionX = -40.0
    }

    private func applyImmediateState(targetCount: Int) {
        self.displayedCount = targetCount
        for i in 0..<Self.maxSlots {
            self.slotOpacities[i] = i < targetCount ? 1.0 : 0.0
            self.slotBounces[i] = 0.0
            self.slotOffsetsX[i] = 0.0
            self.slotScales[i] = i < targetCount ? 1.0 : 0.85
        }
        self.overflowCoolCount = 0
        if isMuted {
            self.holtSpeech = "Silence."
            self.jakeSpeech = nil
            self.holtEyebrowRaised = false
        } else {
            self.holtSpeech = nil
            if targetCount == 10 {
                evaluateEasterEggsOnMaxVolume()
                triggerJakeCelebration(atMax: true)
            } else {
                self.jakeSpeech = nil
                self.holtEyebrowRaised = false
            }
        }
    }

    private func cancelPendingAnimations() {
        for item in pendingWorkItems {
            item.cancel()
        }
        pendingWorkItems.removeAll()

        for i in 0..<Self.maxSlots {
            self.slotBounces[i] = 0.0
            self.slotOffsetsX[i] = 0.0
            if i < displayedCount {
                self.slotOpacities[i] = 1.0
                self.slotScales[i] = 1.0
            } else {
                self.slotOpacities[i] = 0.0
                self.slotScales[i] = 0.85
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

    public func setHoltPatienceForTesting(_ patience: Double) {
        self.holtPatience = patience
    }

    public func setOverflowCoolCountForTesting(_ count: Int) {
        self.overflowCoolCount = count
    }

    public func triggerCheddarForTesting() {
        self.cheddarActive = true
        self.cheddarPositionX = 120.0
    }
    #endif
}
