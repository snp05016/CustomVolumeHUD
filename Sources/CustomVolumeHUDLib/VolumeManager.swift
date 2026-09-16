import Foundation
import CoreAudio
import AudioToolbox
import QuartzCore

/// Manages system volume and mute states using macOS CoreAudio APIs.
public final class VolumeManager: @unchecked Sendable {
    public static let shared = VolumeManager()

    public var onVolumeChanged: (@MainActor (Float, Bool) -> Void)?

    private var currentDeviceID: AudioObjectID = 0
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var muteListenerBlock: AudioObjectPropertyListenerBlock?
    private var lastDirectAdjustmentTime: TimeInterval = 0
    private var batteryCache: (deviceName: String, percentage: Int?, timestamp: TimeInterval)?

    public var lastDirectAdjustmentTimestamp: TimeInterval {
        lastDirectAdjustmentTime
    }

    /// Metadata for the active output when CoreAudio reports a Bluetooth transport.
    public var bluetoothOutputDevice: BluetoothOutputDevice? {
        guard let device = currentOutputDevice, device.isBluetooth else { return nil }
        return BluetoothOutputDevice(
            name: device.name,
            batteryPercentage: cachedBatteryPercentage(for: device.name)
        )
    }

    public var currentOutputDevice: AudioOutputDevice? {
        guard currentDeviceID != 0 else { return nil }
        return outputDevice(for: currentDeviceID)
    }

    public var availableOutputDevices: [AudioOutputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        guard count > 0 else { return [] }
        var deviceIDs = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceIDs
        ) == noErr else { return [] }

        return deviceIDs
            .filter { isAliveOutputDevice($0) }
            .compactMap(outputDevice(for:))
    }

    /// Cycles the macOS default output and also updates the system-sound output when possible.
    @discardableResult
    public func cycleOutputDevice(direction: Int) -> AudioOutputDevice? {
        let devices = availableOutputDevices
        guard devices.count > 1,
              let currentIndex = devices.firstIndex(where: { $0.id == currentDeviceID }),
              let nextIndex = AudioOutputDevice.cycledIndex(
                currentIndex: currentIndex,
                count: devices.count,
                direction: direction
              ) else {
            return currentOutputDevice
        }

        let nextDevice = devices[nextIndex]
        guard setDefaultOutputDevice(AudioObjectID(nextDevice.id)) else { return currentOutputDevice }
        updateDefaultDevice()
        batteryCache = nil
        return currentOutputDevice ?? nextDevice
    }

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
            self.batteryCache = nil
            setupPropertyListeners()
        }
    }

    private func outputDevice(for deviceID: AudioObjectID) -> AudioOutputDevice? {
        guard let name = deviceName(for: deviceID), let transport = transportType(for: deviceID) else {
            return nil
        }
        return AudioOutputDevice(id: UInt32(deviceID), name: name, transportType: transport)
    }

    private func deviceName(for deviceID: AudioObjectID) -> String? {
        var unmanagedName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &unmanagedName) == noErr else {
            return nil
        }
        return unmanagedName?.takeRetainedValue() as String?
    }

    private func transportType(for deviceID: AudioObjectID) -> UInt32? {
        var transportType: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transportType) == noErr else {
            return nil
        }
        return transportType
    }

    private func isAliveOutputDevice(_ deviceID: AudioObjectID) -> Bool {
        var isAlive: UInt32 = 1
        var aliveSize = UInt32(MemoryLayout<UInt32>.size)
        var aliveAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &aliveAddress, 0, nil, &aliveSize, &isAlive) == noErr,
           isAlive == 0 {
            return false
        }

        var streamAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var streamSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize) == noErr,
              streamSize >= MemoryLayout<AudioBufferList>.size else {
            return false
        }

        let storage = UnsafeMutableRawPointer.allocate(
            byteCount: Int(streamSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { storage.deallocate() }
        let bufferList = storage.bindMemory(to: AudioBufferList.self, capacity: 1)
        guard AudioObjectGetPropertyData(deviceID, &streamAddress, 0, nil, &streamSize, bufferList) == noErr else {
            return false
        }
        return UnsafeMutableAudioBufferListPointer(bufferList).contains { $0.mNumberChannels > 0 }
    }

    private func setDefaultOutputDevice(_ deviceID: AudioObjectID) -> Bool {
        var mutableDeviceID = deviceID
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        var outputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let outputStatus = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &outputAddress,
            0,
            nil,
            size,
            &mutableDeviceID
        )
        guard outputStatus == noErr else { return false }

        var systemAddress = outputAddress
        systemAddress.mSelector = kAudioHardwarePropertyDefaultSystemOutputDevice
        _ = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &systemAddress,
            0,
            nil,
            size,
            &mutableDeviceID
        )
        return true
    }

    private func cachedBatteryPercentage(for deviceName: String) -> Int? {
        let now = CACurrentMediaTime()
        if let batteryCache,
           batteryCache.deviceName == deviceName,
           now - batteryCache.timestamp < 30 {
            return batteryCache.percentage
        }

        let percentage = BluetoothBatteryReader.percentage(forDeviceNamed: deviceName)
        batteryCache = (deviceName, percentage, now)
        return percentage
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
            // A route change is not a user volume action. Presenting here races the
            // dedicated DeviceArrivalHUD and makes the B99 volume HUD appear first
            // when AirPods connect. Property listeners still report genuine volume
            // and mute changes, while Option+Volume output switching is presented by
            // MediaKeyInterceptor with explicit output metadata.
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
            let now = CACurrentMediaTime()
            if (now - self.lastDirectAdjustmentTime) < 0.15 {
                // Suppress redundant echo callback from our own direct adjustment
                return
            }
            let vol = self.volume
            let muted = self.isMuted
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.onVolumeChanged?(vol, muted)
                }
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
            let now = CACurrentMediaTime()
            if (now - self.lastDirectAdjustmentTime) < 0.15 {
                // Suppress redundant echo callback from our own direct adjustment
                return
            }
            let vol = self.volume
            let muted = self.isMuted
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.onVolumeChanged?(vol, muted)
                }
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
    public var volume: Float {
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
            if status == noErr {
                return vol
            }

            // Fallback to kAudioDevicePropertyVolumeScalar for non-standard devices
            address.mSelector = kAudioDevicePropertyVolumeScalar
            let scalarStatus = AudioObjectGetPropertyData(currentDeviceID, &address, 0, nil, &size, &vol)
            return scalarStatus == noErr ? vol : 0.0
        }
        set {
            lastDirectAdjustmentTime = CACurrentMediaTime()
            guard currentDeviceID != 0 else { return }
            var newVol = max(0.0, min(1.0, newValue))
            let size = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            var settable: DarwinBoolean = false
            if AudioObjectIsPropertySettable(currentDeviceID, &address, &settable) == noErr && settable.boolValue {
                AudioObjectSetPropertyData(currentDeviceID, &address, 0, nil, size, &newVol)
            } else {
                address.mSelector = kAudioDevicePropertyVolumeScalar
                AudioObjectSetPropertyData(currentDeviceID, &address, 0, nil, size, &newVol)
            }
        }
    }

    /// Whether output audio is muted
    public var isMuted: Bool {
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
            lastDirectAdjustmentTime = CACurrentMediaTime()
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
    public func stepUp(step: Float = 1.0 / 16.0) {
        lastDirectAdjustmentTime = CACurrentMediaTime()
        if isMuted {
            isMuted = false
        }
        volume = min(1.0, volume + step)
    }

    /// Step volume down (by standard macOS 1/16th increment, or smaller if requested)
    public func stepDown(step: Float = 1.0 / 16.0) {
        lastDirectAdjustmentTime = CACurrentMediaTime()
        if isMuted {
            isMuted = false
        }
        volume = max(0.0, volume - step)
    }

    /// Toggle mute
    public func toggleMute() {
        lastDirectAdjustmentTime = CACurrentMediaTime()
        isMuted.toggle()
    }
}
