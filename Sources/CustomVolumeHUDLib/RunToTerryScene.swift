import Foundation

/// Value state consumed by SwiftUI. The physics engine remains independent of rendering.
public struct RunToTerryRenderState: Equatable, Sendable {
    public var visualProgress: Double = 0
    public var targetProgress: Double = 0
    public var velocity: Double = 0
    public var frameIndex: Int = 0
    public var isMoving: Bool = false
    public var direction: Int = 1
    public var isCaught: Bool = false
    public var jakeOffsetY: CGFloat = 0
    public var jakeLeanX: CGFloat = 0
    public var terryReactionLevel: Double = 0
    public var terryOffsetY: CGFloat = 0
    public var catchScale: CGFloat = 1
    public var catchOffsetY: CGFloat = 0
    public var jakeSpeech: String?
    public var terrySpeech: String?

    public init() {}
}

/// Elapsed-time-driven game-style movement for the Jake/Terry scene.
/// It owns no timer; VolumeHUDViewModel's single display loop drives it.
final class RunToTerrySceneEngine {
    private(set) var state = RunToTerryRenderState()

    private var spriteFrameAccumulator: TimeInterval = 0
    private var motionClock: TimeInterval = 0
    private var catchReadyDuration: TimeInterval = 0
    private var speechTimeRemaining: TimeInterval = 0
    private var maxBoundaryPresses = 0
    private var minBoundaryPresses = 0

    func reset(volume: Float, isMuted: Bool) {
        let progress = isMuted ? 0.0 : Double(max(0, min(1, volume)))
        state = RunToTerryRenderState()
        state.visualProgress = progress
        state.targetProgress = progress
        state.isCaught = !isMuted && progress >= 0.999
        state.terryReactionLevel = reactionLevel(for: progress)
        spriteFrameAccumulator = 0
        motionClock = 0
        catchReadyDuration = 0
        speechTimeRemaining = 0
        maxBoundaryPresses = 0
        minBoundaryPresses = 0
    }

    func updateTarget(
        volume: Float,
        isMuted: Bool,
        inputAction: HUDInputAction,
        isRepeatedBoundaryPress: Bool,
        intensityMode: IntensityMode,
        easterEggController: EasterEggController
    ) {
        let progress = isMuted ? 0.0 : Double(max(0, min(1, volume)))
        state.targetProgress = progress

        if progress < 0.999 {
            maxBoundaryPresses = 0
            if state.isCaught {
                // Terry puts Jake down exactly where the running scene resumes.
                state.isCaught = false
                state.visualProgress = max(state.visualProgress, 0.975)
                state.direction = -1
                state.catchScale = 1
                state.catchOffsetY = 0
            }
        }

        if progress > 0.001 {
            minBoundaryPresses = 0
        }

        if inputAction.isVolumeIncrease && isRepeatedBoundaryPress && progress >= 0.999 && !isMuted {
            maxBoundaryPresses += 1
            easterEggController.registerChaosEvent(amount: 0.07)
            state.catchScale = max(state.catchScale, maxBoundaryPresses.isMultiple(of: 2) ? 1.035 : 1.022)
            state.catchOffsetY = -CGFloat(min(2, maxBoundaryPresses))

            if maxBoundaryPresses >= 2 {
                state.terrySpeech = maxBoundaryPresses >= 4 ? "ENOUGH, JAKE." : "DAMMIT, JAKE!"
                state.jakeSpeech = nil
                speechTimeRemaining = 1.15
            } else if easterEggController.attemptTrigger(
                .nineNine,
                probabilityMultiplier: intensityMode.easterEggMultiplier
            ) {
                state.jakeSpeech = "NINE-NINE!"
                state.terrySpeech = nil
                speechTimeRemaining = 1.0
            }
        }

        if inputAction.isVolumeDecrease && isRepeatedBoundaryPress && progress <= 0.001 && !isMuted {
            minBoundaryPresses += 1
            easterEggController.registerChaosEvent(amount: 0.05)
            state.jakeSpeech = minBoundaryPresses >= 3 ? "STILL ZERO!" : "CAN'T GO LOWER!"
            state.terrySpeech = minBoundaryPresses >= 4 ? "ZERO, JAKE." : nil
            state.direction = -1
            state.jakeLeanX = -2
            speechTimeRemaining = 1.15
        }

        if isMuted {
            state.isCaught = false
            state.jakeSpeech = nil
            state.terrySpeech = "QUIET TIME."
            speechTimeRemaining = 0.9
        }
    }

    func snapToTarget() {
        state.visualProgress = state.targetProgress
        state.velocity = 0
        state.isMoving = false
        state.frameIndex = 0
        state.jakeOffsetY = 0
        state.jakeLeanX = 0
        state.isCaught = state.targetProgress >= 0.999
        state.terryReactionLevel = reactionLevel(for: state.visualProgress)
    }

    func tick(deltaTime rawDeltaTime: TimeInterval, inputIntensity: Double) {
        let dt = max(0.001, min(0.05, rawDeltaTime))
        motionClock += dt

        if speechTimeRemaining > 0 {
            speechTimeRemaining -= dt
            if speechTimeRemaining <= 0 {
                state.jakeSpeech = nil
                state.terrySpeech = nil
            }
        }

        settleCatchPose(deltaTime: dt)

        if state.isCaught && state.targetProgress >= 0.999 {
            state.velocity = 0
            state.isMoving = false
            state.frameIndex = 0
            state.terryReactionLevel = 1
            state.terryOffsetY = 0
            return
        }

        let difference = state.targetProgress - state.visualProgress
        if abs(difference) > 0.0005 {
            // Exponential convergence cannot overshoot and catches large jumps in roughly 150-300 ms.
            let response = 12.0 + (inputIntensity * 10.0) + (min(1.0, abs(difference) * 2.0) * 7.0)
            let movementFraction = 1.0 - exp(-response * dt)
            let previous = state.visualProgress
            state.visualProgress += difference * movementFraction
            state.visualProgress = max(0, min(1, state.visualProgress))
            state.velocity = (state.visualProgress - previous) / dt
            state.isMoving = true
            state.direction = state.velocity < 0 ? -1 : 1

            updateRunningFrames(deltaTime: dt, inputIntensity: inputIntensity)
        } else {
            state.visualProgress = state.targetProgress
            state.velocity = 0
            state.isMoving = false
            state.frameIndex = 0
            state.jakeOffsetY = 0
            state.jakeLeanX = 0
            spriteFrameAccumulator = 0
        }

        state.terryReactionLevel = reactionLevel(for: state.visualProgress)
        if state.terryReactionLevel > 0.72 && state.isMoving {
            state.terryOffsetY = Int(motionClock * 10).isMultiple(of: 2) ? -1 : 0
        } else {
            state.terryOffsetY = 0
        }

        updateCatchTransition(deltaTime: dt)
    }

    private func updateRunningFrames(deltaTime: TimeInterval, inputIntensity: Double) {
        let velocityEnergy = min(1.0, abs(state.velocity) / 3.2)
        let energy = max(inputIntensity, velocityEnergy)
        let framesPerSecond = 5.0 + (11.0 * energy)

        spriteFrameAccumulator += deltaTime
        let frameDuration = 1.0 / framesPerSecond
        if spriteFrameAccumulator >= frameDuration {
            spriteFrameAccumulator.formTruncatingRemainder(dividingBy: frameDuration)
            state.frameIndex = state.frameIndex == 0 ? 1 : 0
        }

        let bob: CGFloat = state.frameIndex == 0 ? -1 : 1
        state.jakeOffsetY = bob * CGFloat(0.75 + energy)
        state.jakeLeanX = CGFloat(state.direction) * CGFloat(1.0 + energy)
    }

    private func updateCatchTransition(deltaTime: TimeInterval) {
        guard state.targetProgress >= 0.999 else {
            catchReadyDuration = 0
            return
        }

        if state.visualProgress >= 0.975 {
            catchReadyDuration += deltaTime
            state.isMoving = true
            // A short collision beat makes the combined sprite read as a catch, not a replacement.
            if catchReadyDuration < 0.055 {
                state.jakeLeanX = 2
                state.jakeOffsetY = 1
                state.terryOffsetY = -1
            } else if catchReadyDuration >= 0.105 {
                state.isCaught = true
                state.visualProgress = 1
                state.velocity = 0
                state.isMoving = false
                state.catchScale = 1.035
                state.catchOffsetY = -2
                state.jakeOffsetY = 0
                state.terryOffsetY = 0
            }
        }
    }

    private func settleCatchPose(deltaTime: TimeInterval) {
        let factor = CGFloat(1.0 - exp(-14.0 * deltaTime))
        state.catchScale += (1 - state.catchScale) * factor
        state.catchOffsetY += (0 - state.catchOffsetY) * factor
        if abs(state.catchScale - 1) < 0.001 { state.catchScale = 1 }
        if abs(state.catchOffsetY) < 0.1 { state.catchOffsetY = 0 }
    }

    private func reactionLevel(for progress: Double) -> Double {
        switch progress {
        case ..<0.70: return 0
        case ..<0.85: return (progress - 0.70) / 0.15 * 0.33
        case ..<0.95: return 0.33 + ((progress - 0.85) / 0.10 * 0.34)
        default: return min(1, 0.67 + ((progress - 0.95) / 0.05 * 0.33))
        }
    }
}
