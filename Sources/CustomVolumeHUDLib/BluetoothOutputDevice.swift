import Foundation

public enum BluetoothDeviceKind: String, Equatable, Sendable {
    case earbuds
    case headphones

    public var assetName: String {
        switch self {
        case .earbuds: "bluetooth_earbuds"
        case .headphones: "bluetooth_headphones"
        }
    }
}

/// Display-safe metadata for the currently selected Bluetooth audio output.
public struct BluetoothOutputDevice: Equatable, Sendable {
    public let name: String
    public let kind: BluetoothDeviceKind
    public let batteryPercentage: Int?

    public init(name: String, batteryPercentage: Int? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmedName.isEmpty ? "Bluetooth Audio" : trimmedName
        self.kind = Self.classify(name: self.name)
        self.batteryPercentage = batteryPercentage.map { min(100, max(0, $0)) }
    }

    public var assetName: String { kind.assetName }

    /// A compact model-oriented label that fits the HUD's 5x7 pixel font.
    public var displayName: String {
        let normalized = Self.normalized(name)

        if normalized.contains("AIRPODS MAX") { return "AIRPODS MAX" }
        if normalized.contains("AIRPODS PRO") { return "AIRPODS PRO" }
        if normalized.contains("AIRPODS") { return "AIRPODS" }
        if normalized.contains("BEATS FIT PRO") { return "BEATS FIT PRO" }
        if normalized.contains("STUDIO BUDS") { return "STUDIO BUDS" }

        return String(normalized.prefix(16))
    }

    public static func classify(name: String) -> BluetoothDeviceKind {
        let normalized = normalized(name)

        let headphoneMarkers = [
            "AIRPODS MAX", "HEADPHONE", "HEADSET", "WH-", "QC ",
            "MOMENTUM", "ATH-", "STUDIO3", "STUDIO PRO", "SOLO"
        ]
        if headphoneMarkers.contains(where: normalized.contains) {
            return .headphones
        }

        let earbudMarkers = [
            "AIRPOD", "EARBUD", "EARPHONE", "IN-EAR", "BUDS", "BUD ",
            "FREEBUD", "GALAXY BUD", "PIXEL BUD", "WF-", "FIT PRO", "POWERBEATS"
        ]
        if earbudMarkers.contains(where: normalized.contains) {
            return .earbuds
        }

        // Most unnamed Bluetooth audio outputs expose a headset profile.
        return .headphones
    }

    static func normalized(_ name: String) -> String {
        let folded = name
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .uppercased()
            .replacingOccurrences(of: "’", with: "'")

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -"))
        let asciiSafe = folded.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : " " }
        return String(asciiSafe)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
