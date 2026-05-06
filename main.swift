import Cocoa

// ============================================================================
// MARK: - Entry Point
// ============================================================================
//
// Type declarations live under Sources/. Top-level executable code (asset
// validation + NSApplication bootstrap) must remain in main.swift — Swift
// requires either a designated main.swift or @main, and we use the former
// to keep the build script (raw `swiftc`) trivial.

func resolvePackPath() -> String {
    let fm = FileManager.default
    // 1. CLI argument
    if CommandLine.arguments.count > 1 {
        return CommandLine.arguments[1]
    }
    // 2. .app bundle Resources
    if Bundle.main.bundlePath.hasSuffix(".app"),
       let resPath = Bundle.main.resourcePath {
        let bundled = resPath + "/Kittens pack"
        if fm.fileExists(atPath: bundled) { return bundled }
    }
    // 3. Auto-detect: next to executable, then ~/Downloads
    let execDir = (CommandLine.arguments[0] as NSString).deletingLastPathComponent
    let candidate = execDir + "/Kittens pack"
    if fm.fileExists(atPath: candidate) { return candidate }
    return NSHomeDirectory() + "/Downloads/Kittens pack"
}

Config.packPath = resolvePackPath()

// Validate assets exist
let fm = FileManager.default
if !fm.fileExists(atPath: Config.packPath) {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Assets Not Found"
    alert.informativeText = "Could not find 'Kittens pack' at:\n\(Config.packPath)\n\nPlease place the Kittens pack next to the app or in ~/Downloads."
    alert.runModal()
    exit(1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
