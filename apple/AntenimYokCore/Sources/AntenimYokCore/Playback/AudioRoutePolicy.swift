import Foundation

public enum AudioOutputKind: Sendable, Equatable {
    case builtInSpeaker
    case builtInReceiver
    case headphones
    case bluetooth
    case airPlay
    case car
    case other
}

public enum AudioRouteChangeReason: Sendable, Equatable {
    case newDeviceAvailable
    case oldDeviceUnavailable
    case categoryChange
    case override
    case wakeFromSleep
    case noSuitableRouteForCategory
    case routeConfigurationChange
    case unknown
}

/// What to do when the audio route changes (iPhone): pull the plug on headphones / AirPods / car and the radio stops
/// instead of suddenly blaring from the speaker.
public enum AudioRoutePolicy {
    public static func shouldStop(reason: AudioRouteChangeReason, previousOutputs: [AudioOutputKind]) -> Bool {
        guard reason == .oldDeviceUnavailable else { return false }
        return previousOutputs.contains { kind in
            switch kind {
            case .headphones, .bluetooth, .airPlay, .car: true
            case .builtInSpeaker, .builtInReceiver, .other: false
            }
        }
    }
}

public enum AudioInterruptionEvent: Sendable, Equatable {
    case began
    case ended(shouldResume: Bool)
}

public enum AudioInterruptionAction: Sendable, Equatable {
    /// The system paused us (call, Siri, another app): do not treat the pause as the user's.
    case waitForEnd
    case resume
    /// The interruption ended and the system does not want us to resume: stop.
    case stop
}

public enum AudioInterruptionPolicy {
    public static func action(for event: AudioInterruptionEvent) -> AudioInterruptionAction {
        switch event {
        case .began: .waitForEnd
        case .ended(shouldResume: true): .resume
        case .ended(shouldResume: false): .stop
        }
    }
}
