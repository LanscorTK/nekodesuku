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
        let d = UserDefaults.standard
        d.set(Double(scale), forKey: "cfg_scale")
        d.set(Double(walkSpeed), forKey: "cfg_walkSpeed")
        d.set(Double(gravitySpeed), forKey: "cfg_gravity")
        d.set(activityLevel, forKey: "cfg_activity")
        d.set(windowAwareness, forKey: "cfg_windowAwareness")
        d.set(autoSleepMinutes, forKey: "cfg_autoSleep")
    }

    static func restore() {
        let d = UserDefaults.standard
        if d.object(forKey: "cfg_scale") != nil {
            scale = CGFloat(d.double(forKey: "cfg_scale"))
            walkSpeed = CGFloat(d.double(forKey: "cfg_walkSpeed"))
            gravitySpeed = CGFloat(d.double(forKey: "cfg_gravity"))
            activityLevel = d.double(forKey: "cfg_activity")
            if d.object(forKey: "cfg_windowAwareness") != nil {
                windowAwareness = d.bool(forKey: "cfg_windowAwareness")
            }
            if d.object(forKey: "cfg_autoSleep") != nil {
                autoSleepMinutes = d.double(forKey: "cfg_autoSleep")
            }
        }
    }
}
