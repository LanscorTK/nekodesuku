import Cocoa

// ============================================================================
// MARK: - Configuration
// ============================================================================

struct Config {
    static var packPath = ""
    static var scale: CGFloat = 6.0
    static var walkSpeed: CGFloat = 30
    static var gravitySpeed: CGFloat = 80
    static var activityLevel: Double = 1.0  // 0.0=calm, 1.0=normal, 2.0=hyperactive
    static var windowAwareness: Bool = true
    static var autoSleepMinutes: Double = 5.0  // 0 = disabled
    static var breakThresholdMinutes: Int = 60
    static var windowSize: CGFloat { 16.0 * scale }

    static let catNames: [String: String] = [
        "Cat 1": "Gray",      "Cat 2": "Silver",
        "Cat 3": "Black",     "Cat 4": "Orange",
        "Cat 5": "Ash",       "Cat 6": "Tuxedo",
        "Cat 7": "Chocolate", "Cat 8": "Cream",
        "Cat 9": "White",     "Cat 10": "Siamese",
        "Cat 11": "Peach",    "Cat 12": "Brown",
        "Cat 13": "Lilac",
    ]

    static func catDisplayName(_ folder: String) -> String {
        catNames[folder] ?? folder
    }

    static func save() {
        UserDefaultsStore.saveScale(scale)
        UserDefaultsStore.saveWalkSpeed(walkSpeed)
        UserDefaultsStore.saveGravitySpeed(gravitySpeed)
        UserDefaultsStore.saveActivityLevel(activityLevel)
        UserDefaultsStore.saveWindowAwareness(windowAwareness)
        UserDefaultsStore.saveAutoSleepMinutes(autoSleepMinutes)
        UserDefaultsStore.saveBreakThresholdMinutes(breakThresholdMinutes)
    }

    static func restore() {
        scale = UserDefaultsStore.loadScale()
        walkSpeed = UserDefaultsStore.loadWalkSpeed()
        gravitySpeed = UserDefaultsStore.loadGravitySpeed()
        activityLevel = UserDefaultsStore.loadActivityLevel()
        windowAwareness = UserDefaultsStore.loadWindowAwareness()
        autoSleepMinutes = UserDefaultsStore.loadAutoSleepMinutes()
        breakThresholdMinutes = UserDefaultsStore.loadBreakThresholdMinutes()
    }
}
