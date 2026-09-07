import Cocoa

/// Intercepts hardware media keys (Volume Up, Volume Down, Mute)
/// using a low-level CGEventTap to suppress the native macOS volume bezel.
public final class MediaKeyInterceptor: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var muteTogglePending = false

    // System-defined key type codes
    private static let NX_KEYTYPE_SOUND_UP: Int32 = 0
    private static let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
    private static let NX_KEYTYPE_MUTE: Int32 = 7

    public static let standardVolumeStep: Float = 1.0 / 16.0
    public static let fineVolumeStep: Float = 1.0 / 64.0

    public var onVolumeAdjusted: (@MainActor (Float, Bool, HUDInputAction, AudioOutputDevice?) -> Void)?

    public init() {}

    public static func isFineAdjustment(shiftPressed: Bool, optionPressed: Bool) -> Bool {
        shiftPressed && optionPressed
    }

    public static func shouldCycleOutput(shiftPressed: Bool, optionPressed: Bool) -> Bool {
        optionPressed && !shiftPressed
    }

    deinit {
        stop()
    }

    /// Attempts to start intercepting media keys.
    /// Returns true if the event tap was created successfully (requires Accessibility permission).
    @discardableResult
    public func start() -> Bool {
        guard eventTap == nil else { return true }

        let eventMask = (1 << NSEvent.EventType.systemDefined.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                return interceptor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
                self.runLoopSource = nil
            }
            self.eventTap = nil
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap re-enabling if disabled by system timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        }

        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.type == .systemDefined,
              nsEvent.subtype.rawValue == 8 else { // 8 = NX_SUBTYPE_AUX_CONTROL_BUTTONS
            return Unmanaged.passRetained(event)
        }

        let data1 = Int(nsEvent.data1)
        let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
        let keyFlags = (data1 & 0x0000FFFF)
        let keyState = (keyFlags & 0xFF00) >> 8 // 0x0A = Key Down / Repeat, 0x0B = Key Up
        let isRepeat = (keyFlags & 0x1) != 0

        // Only handle sound keys (Volume Up, Volume Down, Mute)
        guard keyCode == Self.NX_KEYTYPE_SOUND_UP ||
              keyCode == Self.NX_KEYTYPE_SOUND_DOWN ||
              keyCode == Self.NX_KEYTYPE_MUTE else {
            return Unmanaged.passRetained(event)
        }

        // On key down / repeated hold, perform authoritative volume adjustment
        if keyState == 0x0A {
            let optionPressed = event.flags.contains(.maskAlternate)
            let shiftPressed = event.flags.contains(.maskShift)
            let isFineTuning = Self.isFineAdjustment(
                shiftPressed: shiftPressed,
                optionPressed: optionPressed
            )

            // Option + Volume cycles outputs; Shift + Option retains native quarter-step behavior.
            if Self.shouldCycleOutput(shiftPressed: shiftPressed, optionPressed: optionPressed),
               keyCode != Self.NX_KEYTYPE_MUTE {
                if !isRepeat {
                    let direction = keyCode == Self.NX_KEYTYPE_SOUND_UP ? 1 : -1
                    let outputDevice = VolumeManager.shared.cycleOutputDevice(direction: direction)
                    notifyChange(
                        action: direction > 0 ? .outputNext : .outputPrevious,
                        outputDevice: outputDevice,
                        feedbackCue: .outputSwitch
                    )
                }
                return nil
            }

            let step = isFineTuning ? Self.fineVolumeStep : Self.standardVolumeStep

            switch keyCode {
            case Self.NX_KEYTYPE_SOUND_UP:
                let oldVolume = VolumeManager.shared.volume
                VolumeManager.shared.stepUp(step: step)
                let newVolume = VolumeManager.shared.volume
                let action: HUDInputAction = isFineTuning ? .fineVolumeUp : .volumeUp
                notifyChange(
                    action: action,
                    feedbackCue: newVolume >= 0.999 && oldVolume < 0.999 ? .maximum : .stepUp
                )

            case Self.NX_KEYTYPE_SOUND_DOWN:
                VolumeManager.shared.stepDown(step: step)
                notifyChange(
                    action: isFineTuning ? .fineVolumeDown : .volumeDown,
                    feedbackCue: .stepDown
                )

            case Self.NX_KEYTYPE_MUTE:
                // Only toggle mute on initial key down; do not oscillate on key repeat hold
                if !isRepeat && !muteTogglePending {
                    if VolumeManager.shared.isMuted {
                        VolumeManager.shared.toggleMute()
                        notifyChange(action: .muteToggle, feedbackCue: .stepUp)
                    } else {
                        muteTogglePending = true
                        // Start the tape-stop while output is still audible, then close mute on its downbeat.
                        DispatchQueue.main.async {
                            ArcadeFeedbackController.shared.perform(cue: .mute)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.075) { [weak self] in
                            VolumeManager.shared.toggleMute()
                            self?.muteTogglePending = false
                            self?.notifyChange(action: .muteToggle, feedbackCue: nil)
                        }
                    }
                }

            default:
                break
            }
        }

        // Swallow BOTH key down (0x0A) and key up (0x0B) for sound keys to suppress native HUD
        return nil
    }

    private func notifyChange(
        action: HUDInputAction,
        outputDevice: AudioOutputDevice? = nil,
        feedbackCue: ArcadeFeedbackCue?
    ) {
        let vol = VolumeManager.shared.volume
        let muted = VolumeManager.shared.isMuted
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                if let feedbackCue {
                    ArcadeFeedbackController.shared.perform(
                        cue: feedbackCue,
                        isFineAdjustment: action.isFineAdjustment
                    )
                }
                self?.onVolumeAdjusted?(vol, muted, action, outputDevice)
            }
        }
    }
}
