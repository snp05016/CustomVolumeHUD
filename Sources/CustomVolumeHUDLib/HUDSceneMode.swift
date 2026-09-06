import Foundation

/// The two complete visualizations available for one HUD interaction session.
public enum HUDSceneMode: String, CaseIterable, Sendable {
    case coolHolt
    case runToTerry

    public static func random() -> HUDSceneMode {
        Bool.random() ? .coolHolt : .runToTerry
    }
}

/// Randomizes each pair while guaranteeing that neither scene can be starved.
/// A bag always contains one Holt scene and one Terry scene in a shuffled order.
public final class HUDSceneSelector {
    public typealias Shuffler = ([HUDSceneMode]) -> [HUDSceneMode]

    private var bag: [HUDSceneMode] = []
    private let shuffler: Shuffler

    public init(shuffler: @escaping Shuffler = { $0.shuffled() }) {
        self.shuffler = shuffler
    }

    public func next() -> HUDSceneMode {
        if bag.isEmpty {
            let candidate = shuffler(HUDSceneMode.allCases)
            let containsEveryMode = candidate.count == HUDSceneMode.allCases.count &&
                Set(candidate) == Set(HUDSceneMode.allCases)
            bag = containsEveryMode ? candidate : HUDSceneMode.allCases.shuffled()
        }
        return bag.removeFirst()
    }
}

/// Identifies the user action even when the system volume is already at a boundary.
public enum HUDInputAction: Equatable, Sendable {
    case inferred
    case volumeUp
    case volumeDown
    case muteToggle
    case externalChange

    var explicitDirection: Int? {
        switch self {
        case .volumeUp: return 1
        case .volumeDown: return -1
        case .muteToggle: return 0
        case .inferred, .externalChange: return nil
        }
    }
}

/// A scene choice is locked to this lifetime and is released only after fade-out completes.
public struct HUDSession: Equatable, Sendable {
    public let id: UUID
    public let sceneMode: HUDSceneMode
    public let startTimestamp: TimeInterval
    public var lastInputTimestamp: TimeInterval

    public init(
        id: UUID = UUID(),
        sceneMode: HUDSceneMode,
        startTimestamp: TimeInterval,
        lastInputTimestamp: TimeInterval
    ) {
        self.id = id
        self.sceneMode = sceneMode
        self.startTimestamp = startTimestamp
        self.lastInputTimestamp = lastInputTimestamp
    }
}
