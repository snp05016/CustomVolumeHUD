import Cocoa

/// Intercepts hardware media keys (Volume Up, Volume Down, Mute)
/// using a low-level CGEventTap to suppress the native macOS volume bezel.
final class MediaKeyInterceptor: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // System-defined key type codes
    private static let NX_KEYTYPE_SOUND_UP: Int32 = 0
    private static let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
    private static let NX_KEYTYPE_MUTE: Int32 = 7

    var onVolumeAdjusted: ((Float, Bool) -> Void)?

    init() {}

    deinit {
        stop()
    }

    /// Attempts to start intercepting media keys.
    /// Returns true if the event tap was created successfully (requires Accessibility permission).
    @discardableResult
    func start() -> Bool {
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

    func stop() {
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
            return Unmanaged.passRetained(event)
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

        // Only handle key down / repeated hold
        if keyState == 0x0A {
            // Check for Shift + Option for 1/4 step fine tuning (1/64th of full scale)
            let isFineTuning = event.flags.contains([.maskAlternate, .maskShift])
            let step: Float = isFineTuning ? (1.0 / 64.0) : (1.0 / 16.0)

            switch keyCode {
            case Self.NX_KEYTYPE_SOUND_UP:
                VolumeManager.shared.stepUp(step: step)
                notifyChange()
                return nil // Swallows the event: suppresses native HUD

            case Self.NX_KEYTYPE_SOUND_DOWN:
                VolumeManager.shared.stepDown(step: step)
                notifyChange()
                return nil // Swallows the event: suppresses native HUD

            case Self.NX_KEYTYPE_MUTE:
                VolumeManager.shared.toggleMute()
                notifyChange()
                return nil // Swallows the event: suppresses native HUD

            default:
                break
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func notifyChange() {
        let vol = VolumeManager.shared.volume
        let muted = VolumeManager.shared.isMuted
        DispatchQueue.main.async { [weak self] in
            self?.onVolumeAdjusted?(vol, muted)
        }
    }
}
