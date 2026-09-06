import Foundation
import CoreAudio
import AudioToolbox

/// Manages system volume and mute states using macOS CoreAudio APIs.
final class VolumeManager: @unchecked Sendable {
    static let shared = VolumeManager()

    var onVolumeChanged: ((Float, Bool) -> Void)?

    private var currentDeviceID: AudioObjectID = 0
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var muteListenerBlock: AudioObjectPropertyListenerBlock?

    private init() {
        updateDefaultDevice()
        setupDeviceChangeListener()
    }

    // MARK: - Device Management

    private func updateDefaultDevice() {
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        if status == noErr && deviceID != 0 {
            removeListeners()
            self.currentDeviceID = deviceID
            setupPropertyListeners()
        }
    }

    private func setupDeviceChangeListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.updateDefaultDevice()
            if let currentVol = self?.volume, let muted = self?.isMuted {
                self?.onVolumeChanged?(currentVol, muted)
            }
        }
    }

    // MARK: - Property Listeners

    private func setupPropertyListeners() {
        guard currentDeviceID != 0 else { return }

        // Volume listener
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let volBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            let vol = self.volume
            let muted = self.isMuted
            DispatchQueue.main.async {
                self.onVolumeChanged?(vol, muted)
            }
        }
        self.volumeListenerBlock = volBlock
        AudioObjectAddPropertyListenerBlock(currentDeviceID, &volAddress, DispatchQueue.main, volBlock)

        // Mute listener
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            let vol = self.volume
            let muted = self.isMuted
            DispatchQueue.main.async {
                self.onVolumeChanged?(vol, muted)
            }
        }
        self.muteListenerBlock = muteBlock
        AudioObjectAddPropertyListenerBlock(currentDeviceID, &muteAddress, DispatchQueue.main, muteBlock)
    }

    private func removeListeners() {
        guard currentDeviceID != 0 else { return }

        if let volBlock = volumeListenerBlock {
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(currentDeviceID, &volAddress, DispatchQueue.main, volBlock)
            self.volumeListenerBlock = nil
        }

        if let muteBlock = muteListenerBlock {
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(currentDeviceID, &muteAddress, DispatchQueue.main, muteBlock)
            self.muteListenerBlock = nil
        }
    }

    // MARK: - Volume & Mute Accessors

    /// Current volume level from 0.0 to 1.0
    var volume: Float {
        get {
            guard currentDeviceID != 0 else { return 0.0 }
            var vol: Float32 = 0.0
            var size = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            let status = AudioObjectGetPropertyData(currentDeviceID, &address, 0, nil, &size, &vol)
            return status == noErr ? vol : 0.0
        }
        set {
            guard currentDeviceID != 0 else { return }
            var newVol = max(0.0, min(1.0, newValue))
            let size = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            AudioObjectSetPropertyData(currentDeviceID, &address, 0, nil, size, &newVol)
        }
    }

    /// Whether output audio is muted
    var isMuted: Bool {
        get {
            guard currentDeviceID != 0 else { return false }
            var muted: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            let status = AudioObjectGetPropertyData(currentDeviceID, &address, 0, nil, &size, &muted)
            return status == noErr && muted == 1
        }
        set {
            guard currentDeviceID != 0 else { return }
            var mutedVal: UInt32 = newValue ? 1 : 0
            let size = UInt32(MemoryLayout<UInt32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            AudioObjectSetPropertyData(currentDeviceID, &address, 0, nil, size, &mutedVal)
        }
    }

    /// Step volume up (by standard macOS 1/16th increment, or smaller if requested)
    func stepUp(step: Float = 1.0 / 16.0) {
        if isMuted {
            isMuted = false
        }
        volume = min(1.0, volume + step)
    }

    /// Step volume down (by standard macOS 1/16th increment)
    func stepDown(step: Float = 1.0 / 16.0) {
        volume = max(0.0, volume - step)
    }

    /// Toggle mute
    func toggleMute() {
        isMuted.toggle()
    }
}
