import CoreAudio
import Foundation

/// CoreAudio metadata used by the keyboard output-device switcher.
public struct AudioOutputDevice: Equatable, Sendable {
    public let id: UInt32
    public let name: String
    public let transportType: UInt32

    public init(id: UInt32, name: String, transportType: UInt32) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Audio Output"
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transportType = transportType
    }

    public var isBluetooth: Bool {
        transportType == kAudioDeviceTransportTypeBluetooth ||
            transportType == kAudioDeviceTransportTypeBluetoothLE
    }

    public var transportLabel: String {
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn: "BUILT-IN"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: "BLUETOOTH"
        case kAudioDeviceTransportTypeUSB: "USB"
        case kAudioDeviceTransportTypeHDMI: "HDMI"
        case kAudioDeviceTransportTypeDisplayPort: "DISPLAY"
        case kAudioDeviceTransportTypeAirPlay: "AIRPLAY"
        case kAudioDeviceTransportTypeThunderbolt: "THUNDERBOLT"
        case kAudioDeviceTransportTypeVirtual: "VIRTUAL"
        default: "OUTPUT"
        }
    }

    public var displayName: String {
        let normalized = BluetoothOutputDevice.normalized(name)
        return String(normalized.prefix(20))
    }

    /// Pure modular cycling logic, separated for deterministic tests.
    public static func cycledIndex(currentIndex: Int, count: Int, direction: Int) -> Int? {
        guard count > 0, currentIndex >= 0, currentIndex < count else { return nil }
        let delta = direction < 0 ? -1 : 1
        return (currentIndex + delta + count) % count
    }
}
