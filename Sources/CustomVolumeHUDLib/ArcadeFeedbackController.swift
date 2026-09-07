import AppKit
import AVFoundation
import Foundation

public enum ArcadeFeedbackCue: Equatable, Sendable {
    case stepUp
    case stepDown
    case maximum
    case mute
    case outputSwitch
}

/// Deterministic 8-bit waveform synthesis. No bundled audio files or decoding latency.
public enum ChiptuneSynthesizer {
    public static func samples(
        for cue: ArcadeFeedbackCue,
        sampleRate: Double = 44_100
    ) -> [Float] {
        switch cue {
        case .stepUp:
            return pitchedClick(frequencies: [620, 790], duration: 0.052, sampleRate: sampleRate)
        case .stepDown:
            return pitchedClick(frequencies: [540, 390], duration: 0.052, sampleRate: sampleRate)
        case .maximum:
            return melody(frequencies: [659, 784, 988, 1_318], noteDuration: 0.065, sampleRate: sampleRate)
        case .mute:
            return tapeStop(duration: 0.19, sampleRate: sampleRate)
        case .outputSwitch:
            return melody(frequencies: [440, 659, 880], noteDuration: 0.047, sampleRate: sampleRate)
        }
    }

    private static func pitchedClick(
        frequencies: [Double],
        duration: Double,
        sampleRate: Double
    ) -> [Float] {
        let count = max(1, Int(duration * sampleRate))
        return (0..<count).map { index in
            let progress = Double(index) / Double(count)
            let frequencyIndex = min(frequencies.count - 1, Int(progress * Double(frequencies.count)))
            let frequency = frequencies[frequencyIndex]
            let phase = 2 * Double.pi * frequency * Double(index) / sampleRate
            let square = sin(phase) >= 0 ? 1.0 : -1.0
            return Float(square * envelope(progress: progress, attack: 0.08, release: 0.42) * 0.095)
        }
    }

    private static func melody(
        frequencies: [Double],
        noteDuration: Double,
        sampleRate: Double
    ) -> [Float] {
        let samplesPerNote = max(1, Int(noteDuration * sampleRate))
        return frequencies.enumerated().flatMap { noteIndex, frequency in
            (0..<samplesPerNote).map { sampleIndex in
                let progress = Double(sampleIndex) / Double(samplesPerNote)
                let absoluteIndex = (noteIndex * samplesPerNote) + sampleIndex
                let phase = 2 * Double.pi * frequency * Double(absoluteIndex) / sampleRate
                let square = sin(phase) >= 0 ? 1.0 : -1.0
                let octave = sin(phase * 2) >= 0 ? 1.0 : -1.0
                return Float(
                    ((square * 0.078) + (octave * 0.022)) *
                        envelope(progress: progress, attack: 0.06, release: 0.25)
                )
            }
        }
    }

    private static func tapeStop(duration: Double, sampleRate: Double) -> [Float] {
        let count = max(1, Int(duration * sampleRate))
        var phase = 0.0
        return (0..<count).map { index in
            let progress = Double(index) / Double(count)
            let frequency = 700 * pow(0.08, progress)
            phase += 2 * Double.pi * frequency / sampleRate
            let square = sin(phase) >= 0 ? 1.0 : -1.0
            let scratch = sin(Double(index) * 1.731) * sin(Double(index) * 0.173)
            let decay = pow(1 - progress, 1.6)
            return Float(((square * 0.075) + (scratch * 0.035)) * decay)
        }
    }

    private static func envelope(progress: Double, attack: Double, release: Double) -> Double {
        let attackGain = min(1, progress / max(0.001, attack))
        let releaseGain = min(1, (1 - progress) / max(0.001, release))
        return max(0, min(attackGain, releaseGain))
    }
}

/// Plays immediate arcade audio and trackpad feedback for intercepted media-key actions.
@MainActor
public final class ArcadeFeedbackController {
    public static let shared = ArcadeFeedbackController()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }

    public func perform(cue: ArcadeFeedbackCue, isFineAdjustment: Bool = false) {
        let hapticPattern: NSHapticFeedbackManager.FeedbackPattern =
            cue == .maximum || cue == .mute ? .levelChange : .alignment
        NSHapticFeedbackManager.defaultPerformer.perform(hapticPattern, performanceTime: .now)

        let samples = ChiptuneSynthesizer.samples(for: cue, sampleRate: format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ), let channel = buffer.floatChannelData?[0] else { return }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (index, sample) in samples.enumerated() {
            channel[index] = sample
        }

        do {
            if !engine.isRunning {
                try engine.start()
            }
            player.volume = isFineAdjustment ? 0.58 : 1.0
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            if !player.isPlaying {
                player.play()
            }
        } catch {
            // Visual feedback remains fully functional when audio hardware is unavailable.
        }
    }
}
