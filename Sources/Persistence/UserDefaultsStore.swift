import Cocoa

enum DefaultsKey {
    static let scale = "cfg_scale"
    static let walkSpeed = "cfg_walkSpeed"
    static let gravity = "cfg_gravity"
    static let activity = "cfg_activity"
    static let windowAwareness = "cfg_windowAwareness"
    static let autoSleep = "cfg_autoSleep"
    static let breakThresholdMinutes = "cfg_breakThresholdMinutes"
    static let idleSwat = "cfg_idleSwat"
    static let savedPets = "savedPets"
}

struct UserDefaultsStore {
    private static let d = UserDefaults.standard

    private static func double(_ key: String, _ fb: Double) -> Double {
        d.object(forKey: key) == nil ? fb : d.double(forKey: key)
    }
    private static func bool(_ key: String, _ fb: Bool) -> Bool {
        d.object(forKey: key) == nil ? fb : d.bool(forKey: key)
    }
    private static func int(_ key: String, _ fb: Int) -> Int {
        d.object(forKey: key) == nil ? fb : d.integer(forKey: key)
    }

    static func loadScale() -> CGFloat { CGFloat(double(DefaultsKey.scale, 6.0)) }
    static func saveScale(_ v: CGFloat) { d.set(Double(v), forKey: DefaultsKey.scale) }

    static func loadWalkSpeed() -> CGFloat { CGFloat(double(DefaultsKey.walkSpeed, 30)) }
    static func saveWalkSpeed(_ v: CGFloat) { d.set(Double(v), forKey: DefaultsKey.walkSpeed) }

    static func loadGravitySpeed() -> CGFloat { CGFloat(double(DefaultsKey.gravity, 80)) }
    static func saveGravitySpeed(_ v: CGFloat) { d.set(Double(v), forKey: DefaultsKey.gravity) }

    static func loadActivityLevel() -> Double { double(DefaultsKey.activity, 1.0) }
    static func saveActivityLevel(_ v: Double) { d.set(v, forKey: DefaultsKey.activity) }

    static func loadWindowAwareness() -> Bool { bool(DefaultsKey.windowAwareness, true) }
    static func saveWindowAwareness(_ v: Bool) { d.set(v, forKey: DefaultsKey.windowAwareness) }

    static func loadAutoSleepMinutes() -> Double { double(DefaultsKey.autoSleep, 5.0) }
    static func saveAutoSleepMinutes(_ v: Double) { d.set(v, forKey: DefaultsKey.autoSleep) }

    static func loadBreakThresholdMinutes() -> Int { int(DefaultsKey.breakThresholdMinutes, 60) }
    static func saveBreakThresholdMinutes(_ v: Int) { d.set(v, forKey: DefaultsKey.breakThresholdMinutes) }

    static func loadIdleSwatMinutes() -> Double { double(DefaultsKey.idleSwat, 5.0) }
    static func saveIdleSwatMinutes(_ v: Double) { d.set(v, forKey: DefaultsKey.idleSwat) }

    static func loadSavedPets() -> [[String: Any]]? {
        d.array(forKey: DefaultsKey.savedPets) as? [[String: Any]]
    }
    static func saveSavedPets(_ data: [[String: Any]]) {
        d.set(data, forKey: DefaultsKey.savedPets)
    }
}
