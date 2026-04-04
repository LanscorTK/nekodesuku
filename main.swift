import Cocoa
import ImageIO

// ============================================================================
// MARK: - Configuration
// ============================================================================

struct Config {
    static var packPath = ""
    static var catFolder = "Cat 1"
    static var catVariant = "Cat 1"
    static let scale: CGFloat = 6.0
    static var windowSize: CGFloat { 16.0 * scale }

    static var currentCatPath: String {
        "\(packPath)/\(catFolder)/\(catVariant)"
    }
}

// ============================================================================
// MARK: - GIF Animation
// ============================================================================

struct AnimFrame {
    let image: NSImage
    let duration: TimeInterval
}

class Animation {
    let frames: [AnimFrame]
    var currentIndex = 0
    var elapsed: TimeInterval = 0
    var loopCount = 0

    var isEmpty: Bool { frames.isEmpty }
    var currentImage: NSImage? { frames.isEmpty ? nil : frames[currentIndex].image }
    var firstImage: NSImage? { frames.first?.image }
    var completedOnce: Bool { loopCount > 0 }

    init(_ frames: [AnimFrame]) { self.frames = frames }

    func reset() {
        currentIndex = 0
        elapsed = 0
        loopCount = 0
    }

    func advance(by dt: TimeInterval) {
        guard !frames.isEmpty else { return }
        elapsed += dt
        while elapsed >= frames[currentIndex].duration {
            elapsed -= frames[currentIndex].duration
            currentIndex += 1
            if currentIndex >= frames.count {
                currentIndex = 0
                loopCount += 1
            }
        }
    }
}

func loadGIF(_ path: String) -> Animation {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return Animation([]) }
    let n = CGImageSourceGetCount(src)
    var frames: [AnimFrame] = []
    let scale = Config.scale

    for i in 0..<n {
        guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }

        // Read frame delay
        var delay: TimeInterval = 0.1
        if let p = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [String: Any],
           let g = p[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
            delay = (g[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double)
                ?? (g[kCGImagePropertyGIFDelayTime as String] as? Double)
                ?? 0.1
        }
        if delay < 0.02 { delay = 0.1 }

        // Scale up with nearest-neighbor for pixel-perfect look
        let w = Int(CGFloat(cg.width) * scale)
        let h = Int(CGFloat(cg.height) * scale)
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { continue }
        ctx.interpolationQuality = .none
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let scaled = ctx.makeImage() else { continue }
        frames.append(AnimFrame(
            image: NSImage(cgImage: scaled, size: NSSize(width: w, height: h)),
            duration: delay
        ))
    }
    return Animation(frames)
}

// ============================================================================
// MARK: - Pet State Machine
// ============================================================================

enum PetState {
    case sitIdle, walkRight, walkLeft, sleeping
    case meowing, yawning, washing, scratching
}

class PetBrain {
    var state: PetState = .sitIdle
    var stateTime: TimeInterval = 0
    var stateDuration: TimeInterval = 4
    var facingRight = true
    let walkSpeed: CGFloat = 30

    var anims: [String: Animation] = [:]
    var currentAnim: Animation?

    func loadAnims() {
        let base = Config.currentCatPath
        let map: [(String, String)] = [
            ("walk_r",    "walk_right.gif"),
            ("walk_l",    "walk_left.gif"),
            ("sleep_r",   "sleep1(r).gif"),
            ("sleep_l",   "sleep1(l).gif"),
            ("meow",      "meow_sit.gif"),
            ("yawn",      "yawn_sit.gif"),
            ("wash",      "wash_sit.gif"),
            ("scratch_r", "scratch(r).gif"),
            ("scratch_l", "scratch(l).gif"),
        ]
        anims.removeAll()
        for (key, file) in map {
            let path = "\(base)/\(file)"
            if FileManager.default.fileExists(atPath: path) {
                anims[key] = loadGIF(path)
            }
        }
    }

    func enter(_ s: PetState) {
        state = s
        stateTime = 0

        switch s {
        case .sitIdle:
            stateDuration = .random(in: 2...6)
            currentAnim = anims["meow"]   // use first frame as idle pose
        case .walkRight:
            facingRight = true
            stateDuration = .random(in: 3...7)
            setAnim("walk_r")
        case .walkLeft:
            facingRight = false
            stateDuration = .random(in: 3...7)
            setAnim("walk_l")
        case .sleeping:
            stateDuration = .random(in: 8...15)
            setAnim(facingRight ? "sleep_r" : "sleep_l")
        case .meowing:   stateDuration = 99; setAnim("meow")
        case .yawning:   stateDuration = 99; setAnim("yawn")
        case .washing:   stateDuration = 99; setAnim("wash")
        case .scratching:
            stateDuration = 99
            setAnim(facingRight ? "scratch_r" : "scratch_l")
        }
    }

    private func setAnim(_ key: String) {
        if let a = anims[key] ?? anims[key.replacingOccurrences(of: "_l", with: "_r")] {
            a.reset()
            currentAnim = a
        }
    }

    /// Returns horizontal movement delta
    func update(dt: TimeInterval) -> CGFloat {
        stateTime += dt
        if case .sitIdle = state {
            // static idle — don't animate
        } else {
            currentAnim?.advance(by: dt)
        }

        var dx: CGFloat = 0
        switch state {
        case .sitIdle:
            if stateTime >= stateDuration { pickNext() }
        case .walkRight:
            dx = walkSpeed * CGFloat(dt)
            if stateTime >= stateDuration { enter(.sitIdle) }
        case .walkLeft:
            dx = -walkSpeed * CGFloat(dt)
            if stateTime >= stateDuration { enter(.sitIdle) }
        case .sleeping:
            if stateTime >= stateDuration {
                enter(Double.random(in: 0...1) < 0.4 ? .yawning : .sitIdle)
            }
        case .meowing, .yawning, .washing, .scratching:
            if currentAnim?.completedOnce == true { enter(.sitIdle) }
        }
        return dx
    }

    var image: NSImage? {
        if case .sitIdle = state { return currentAnim?.firstImage }
        return currentAnim?.currentImage
    }

    private func pickNext() {
        let r = Double.random(in: 0...1)
        switch r {
        case ..<0.25:  enter(.walkRight)
        case ..<0.50:  enter(.walkLeft)
        case ..<0.60:  enter(.sleeping)
        case ..<0.73:  enter(.meowing)
        case ..<0.83:  enter(.yawning)
        case ..<0.93:  enter(.washing)
        default:       enter(.scratching)
        }
    }
}

// ============================================================================
// MARK: - Pet View
// ============================================================================

class PetView: NSView {
    var petImage: NSImage?
    var isDragging = false
    private var dragOffset = NSPoint.zero

    override func draw(_ dirtyRect: NSRect) {
        guard let img = petImage else { return }
        NSGraphicsContext.current?.imageInterpolation = .none
        img.draw(in: bounds)
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with e: NSEvent) {
        isDragging = true
        let wLoc = e.locationInWindow
        let sLoc = window!.convertPoint(toScreen: wLoc)
        dragOffset = NSPoint(
            x: sLoc.x - window!.frame.origin.x,
            y: sLoc.y - window!.frame.origin.y
        )
    }
    override func mouseDragged(with e: NSEvent) {
        guard isDragging, let w = window else { return }
        let s = NSEvent.mouseLocation
        w.setFrameOrigin(NSPoint(x: s.x - dragOffset.x, y: s.y - dragOffset.y))
    }
    override func mouseUp(with e: NSEvent) { isDragging = false }

    override func rightMouseDown(with e: NSEvent) {
        (NSApp.delegate as? AppDelegate)?.showMenu(e)
    }
}

// ============================================================================
// MARK: - App Delegate
// ============================================================================

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var view: PetView!
    var brain: PetBrain!
    var timer: Timer!
    var lastTick: TimeInterval = 0
    var screenBounds: NSRect = .zero

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let screen = NSScreen.main else {
            print("No screen found")
            NSApp.terminate(nil)
            return
        }
        screenBounds = screen.visibleFrame

        brain = PetBrain()
        brain.loadAnims()

        if brain.anims.isEmpty {
            print("No animations found at: \(Config.currentCatPath)")
            print("Make sure 'Kittens pack' is in the same directory or pass the path as argument.")
            NSApp.terminate(nil)
            return
        }

        brain.enter(.sitIdle)

        // Window
        let sz = Config.windowSize
        let frame = NSRect(
            x: screenBounds.midX - sz/2,
            y: screenBounds.minY,
            width: sz, height: sz
        )
        window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        view = PetView(frame: NSRect(x: 0, y: 0, width: sz, height: sz))
        window.contentView = view
        window.makeKeyAndOrderFront(nil)

        lastTick = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer, forMode: .common)
    }

    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastTick
        lastTick = now

        let dx = brain.update(dt: dt)

        if dx != 0 && !view.isDragging {
            var o = window.frame.origin
            o.x += dx
            let minX = screenBounds.minX
            let maxX = screenBounds.maxX - Config.windowSize
            if o.x <= minX { o.x = minX; brain.enter(.walkRight) }
            else if o.x >= maxX { o.x = maxX; brain.enter(.walkLeft) }
            window.setFrameOrigin(o)
        }

        view.petImage = brain.image
        view.needsDisplay = true
    }

    // MARK: Context Menu

    func showMenu(_ event: NSEvent) {
        let menu = NSMenu()

        // Cat selection
        let catMenu = NSMenu()
        for i in 1...13 {
            let item = NSMenuItem(title: "Cat \(i)", action: #selector(pickCat(_:)), keyEquivalent: "")
            item.tag = i
            item.target = self
            if Config.catFolder == "Cat \(i)" { item.state = .on }
            catMenu.addItem(item)
        }
        let catItem = NSMenuItem(title: "Choose Cat", action: nil, keyEquivalent: "")
        catItem.submenu = catMenu
        menu.addItem(catItem)

        // Variant selection
        let varMenu = NSMenu()
        let catDir = "\(Config.packPath)/\(Config.catFolder)"
        if let items = try? FileManager.default.contentsOfDirectory(atPath: catDir) {
            let variants = items.filter { item in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: "\(catDir)/\(item)", isDirectory: &isDir)
                return isDir.boolValue
            }.sorted()
            for v in variants {
                let mi = NSMenuItem(title: v, action: #selector(pickVariant(_:)), keyEquivalent: "")
                mi.representedObject = v
                mi.target = self
                if v == Config.catVariant { mi.state = .on }
                varMenu.addItem(mi)
            }
        }
        if varMenu.numberOfItems > 0 {
            let varItem = NSMenuItem(title: "Color Variant", action: nil, keyEquivalent: "")
            varItem.submenu = varMenu
            menu.addItem(varItem)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))

        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc func pickCat(_ sender: NSMenuItem) {
        let num = sender.tag
        Config.catFolder = "Cat \(num)"
        // Pick first variant
        let catDir = "\(Config.packPath)/Cat \(num)"
        if let items = try? FileManager.default.contentsOfDirectory(atPath: catDir) {
            let variants = items.filter { item in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: "\(catDir)/\(item)", isDirectory: &isDir)
                return isDir.boolValue
            }.sorted()
            Config.catVariant = variants.first ?? "Cat \(num)"
        }
        brain.loadAnims()
        brain.enter(.sitIdle)
    }

    @objc func pickVariant(_ sender: NSMenuItem) {
        guard let v = sender.representedObject as? String else { return }
        Config.catVariant = v
        brain.loadAnims()
        brain.enter(.sitIdle)
    }
}

// ============================================================================
// MARK: - Main
// ============================================================================

// Resolve pack path
if CommandLine.arguments.count > 1 {
    Config.packPath = CommandLine.arguments[1]
} else {
    let execDir = (CommandLine.arguments[0] as NSString).deletingLastPathComponent
    let candidate = execDir + "/Kittens pack"
    Config.packPath = FileManager.default.fileExists(atPath: candidate)
        ? candidate
        : NSHomeDirectory() + "/Downloads/Kittens pack"
}

if CommandLine.arguments.count > 2 { Config.catFolder = CommandLine.arguments[2] }
if CommandLine.arguments.count > 3 { Config.catVariant = CommandLine.arguments[3] }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
