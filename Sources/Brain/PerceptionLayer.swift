import Cocoa
import CoreGraphics

enum TimeOfDay {
    case morning, afternoon, evening, night

    static func current() -> TimeOfDay {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5...11: return .morning
        case 12...17: return .afternoon
        case 18...22: return .evening
        default: return .night
        }
    }
}

struct Perception {
    let idleTimeSeconds: Double
    let activeAppBundleID: String?
    let timeOfDayBucket: TimeOfDay
    let continuousScreenTimeSeconds: Double
}

final class PerceptionLayer {
    static let shared = PerceptionLayer()
    private init() {}

    private(set) var cached = Perception(
        idleTimeSeconds: 0,
        activeAppBundleID: nil,
        timeOfDayBucket: .afternoon,
        continuousScreenTimeSeconds: 0
    )
    private var continuousScreenTimeSeconds: Double = 0
    private var lastUpdate: TimeInterval = 0

    /// Refresh the cached perception. Owned by AppDelegate.tick (single caller).
    /// Self-throttled to ~1Hz so it's safe to invoke every frame.
    func update() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = lastUpdate == 0 ? 0 : (now - lastUpdate)
        guard dt >= 0.95 else { return }
        lastUpdate = now

        guard let anyEvent = CGEventType(rawValue: ~0) else { return }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)

        if idle < 30 {
            continuousScreenTimeSeconds += dt
        } else {
            continuousScreenTimeSeconds = 0
        }

        cached = Perception(
            idleTimeSeconds: idle,
            activeAppBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            timeOfDayBucket: TimeOfDay.current(),
            continuousScreenTimeSeconds: continuousScreenTimeSeconds
        )
    }

    func current() -> Perception { cached }
}
