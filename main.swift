import Cocoa
import ImageIO

// ============================================================================
// MARK: - Configuration
// ============================================================================

struct Config {
    static var packPath = ""
    static let scale: CGFloat = 6.0
    static var windowSize: CGFloat { 16.0 * scale }
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

        var delay: TimeInterval = 0.1
        if let p = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [String: Any],
           let g = p[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
            delay = (g[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double)
                ?? (g[kCGImagePropertyGIFDelayTime as String] as? Double)
                ?? 0.1
        }
        if delay < 0.02 { delay = 0.1 }

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

struct Movement {
    var dx: CGFloat = 0
    var breathOffset: CGFloat = 0
}

class PetBrain {
    var state: PetState = .sitIdle
    var stateTime: TimeInterval = 0
    var stateDuration: TimeInterval = 4
    var facingRight = true
    let walkSpeed: CGFloat = 30
    var transitionDelay: TimeInterval = 0

    var anims: [String: Animation] = [:]
    var currentAnim: Animation?

    func loadAnims(catPath: String) {
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
            let path = "\(catPath)/\(file)"
            if FileManager.default.fileExists(atPath: path) {
                anims[key] = loadGIF(path)
            }
        }
    }

    func enter(_ s: PetState) {
        state = s
        stateTime = 0
        transitionDelay = 0.15

        switch s {
        case .sitIdle:
            stateDuration = .random(in: 3...7)
            currentAnim = anims["meow"] ?? anims.values.first
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

    func update(dt: TimeInterval) -> Movement {
        stateTime += dt
        var move = Movement()

        if transitionDelay > 0 {
            transitionDelay -= dt
        } else if case .sitIdle = state {
            // static idle — no frame advance
        } else {
            currentAnim?.advance(by: dt)
        }

        // Subtle breathing bob while idle
        if case .sitIdle = state {
            move.breathOffset = sin(stateTime * 2.0) * 1.5
        }

        switch state {
        case .sitIdle:
            if stateTime >= stateDuration { pickNext() }
        case .walkRight:
            if transitionDelay <= 0 { move.dx = walkSpeed * CGFloat(dt) }
            if stateTime >= stateDuration { enter(.sitIdle) }
        case .walkLeft:
            if transitionDelay <= 0 { move.dx = -walkSpeed * CGFloat(dt) }
            if stateTime >= stateDuration { enter(.sitIdle) }
        case .sleeping:
            if stateTime >= stateDuration {
                enter(Double.random(in: 0...1) < 0.4 ? .yawning : .sitIdle)
            }
        case .meowing, .yawning, .washing, .scratching:
            if currentAnim?.completedOnce == true { enter(.sitIdle) }
        }
        return move
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
    var breathOffset: CGFloat = 0
    var isDragging = false
    var gravityEnabled = true
    private var wasDragged = false
    weak var instance: PetInstance?
    private var dragOffset = NSPoint.zero
    private var mouseDownPos = NSPoint.zero

    override func draw(_ dirtyRect: NSRect) {
        guard let img = petImage else { return }
        NSGraphicsContext.current?.imageInterpolation = .none
        var r = bounds
        r.origin.y += breathOffset
        img.draw(in: r)
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with e: NSEvent) {
        isDragging = true
        wasDragged = false
        let sLoc = window!.convertPoint(toScreen: e.locationInWindow)
        mouseDownPos = sLoc
        dragOffset = NSPoint(
            x: sLoc.x - window!.frame.origin.x,
            y: sLoc.y - window!.frame.origin.y
        )
    }

    override func mouseDragged(with e: NSEvent) {
        guard isDragging, let w = window else { return }
        let s = NSEvent.mouseLocation
        let dist = hypot(s.x - mouseDownPos.x, s.y - mouseDownPos.y)
        if dist > 3 {
            wasDragged = true
            gravityEnabled = true
        }
        w.setFrameOrigin(NSPoint(x: s.x - dragOffset.x, y: s.y - dragOffset.y))
    }

    override func mouseUp(with e: NSEvent) {
        // Clicked without dragging = caught mid-fall, stay put
        if !wasDragged { gravityEnabled = false }
        isDragging = false
    }

    override func rightMouseDown(with e: NSEvent) {
        guard let inst = instance else { return }
        (NSApp.delegate as? AppDelegate)?.showPetMenu(for: inst, event: e)
    }
}

// ============================================================================
// MARK: - Pet Instance
// ============================================================================

class PetInstance {
    let window: NSWindow
    let view: PetView
    let brain: PetBrain
    var catFolder: String
    var catVariant: String
    var lastTick: TimeInterval

    var catPath: String { "\(Config.packPath)/\(catFolder)/\(catVariant)" }

    init(catFolder: String, catVariant: String, startX: CGFloat, bottomY: CGFloat) {
        self.catFolder = catFolder
        self.catVariant = catVariant
        self.lastTick = ProcessInfo.processInfo.systemUptime

        let sz = Config.windowSize
        window = NSWindow(
            contentRect: NSRect(x: startX, y: bottomY, width: sz, height: sz),
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

        brain = PetBrain()
        brain.loadAnims(catPath: catPath)
        brain.enter(.sitIdle)

        view.instance = self
        window.makeKeyAndOrderFront(nil)
    }

    func tick(screenBounds: NSRect) {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastTick
        lastTick = now

        let move = brain.update(dt: dt)

        if !view.isDragging {
            var origin = window.frame.origin

            // Gravity: drift to bottom (disabled once caught mid-fall)
            let bottomY = screenBounds.minY
            if view.gravityEnabled && origin.y > bottomY + 2 {
                origin.y = max(bottomY, origin.y - 80 * CGFloat(dt))
            }

            // Horizontal movement
            origin.x += move.dx
            let minX = screenBounds.minX
            let maxX = screenBounds.maxX - Config.windowSize
            if origin.x <= minX { origin.x = minX; brain.enter(.walkRight) }
            else if origin.x >= maxX { origin.x = maxX; brain.enter(.walkLeft) }

            window.setFrameOrigin(origin)
        }

        view.breathOffset = move.breathOffset
        view.petImage = brain.image
        view.needsDisplay = true
    }

    func changeCat(folder: String, variant: String) {
        catFolder = folder
        catVariant = variant
        brain.loadAnims(catPath: catPath)
        brain.enter(.sitIdle)
    }

    func close() {
        window.orderOut(nil)
    }
}

// ============================================================================
// MARK: - App Delegate
// ============================================================================

class AppDelegate: NSObject, NSApplicationDelegate {
    var pets: [PetInstance] = []
    var timer: Timer!
    var screenBounds: NSRect = .zero
    var statusItem: NSStatusItem!
    var menuTargetPet: PetInstance?

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let screen = NSScreen.main else {
            print("No screen found"); NSApp.terminate(nil); return
        }
        screenBounds = screen.visibleFrame

        addPet(catFolder: "Cat 1", catVariant: "Cat 1")

        if pets.isEmpty {
            print("No animations found. Check 'Kittens pack' path.")
            NSApp.terminate(nil); return
        }

        setupStatusBar()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer, forMode: .common)
    }

    func tick() {
        if let screen = NSScreen.main { screenBounds = screen.visibleFrame }
        for pet in pets { pet.tick(screenBounds: screenBounds) }
    }

    // MARK: - Status Bar

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐱"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func rebuildStatusMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        let addItem = NSMenuItem(title: "Add Cat", action: #selector(addRandomPet), keyEquivalent: "n")
        addItem.target = self
        menu.addItem(addItem)

        if pets.count > 1 {
            let rmItem = NSMenuItem(title: "Remove Last Cat", action: #selector(removeLastPet), keyEquivalent: "")
            rmItem.target = self
            menu.addItem(rmItem)
        }

        menu.addItem(.separator())

        for (i, pet) in pets.enumerated() {
            let title = "Cat #\(i + 1): \(pet.catVariant)"
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for c in 1...13 {
                let ci = NSMenuItem(title: "Cat \(c)", action: #selector(statusChangeCat(_:)), keyEquivalent: "")
                ci.tag = i * 100 + c
                ci.target = self
                if pet.catFolder == "Cat \(c)" { ci.state = .on }
                sub.addItem(ci)
            }
            item.submenu = sub
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
    }

    @objc func addRandomPet() {
        let catNum = Int.random(in: 1...13)
        let folder = "Cat \(catNum)"
        addPet(catFolder: folder, catVariant: findFirstVariant(folder: folder))
    }

    @objc func removeLastPet() {
        guard pets.count > 1 else { return }
        pets.removeLast().close()
    }

    @objc func statusChangeCat(_ sender: NSMenuItem) {
        let petIdx = sender.tag / 100
        let catNum = sender.tag % 100
        guard petIdx < pets.count else { return }
        let folder = "Cat \(catNum)"
        pets[petIdx].changeCat(folder: folder, variant: findFirstVariant(folder: folder))
    }

    // MARK: - Per-Pet Context Menu

    func showPetMenu(for pet: PetInstance, event: NSEvent) {
        menuTargetPet = pet
        let menu = NSMenu()

        // Choose Cat
        let catSub = NSMenu()
        for i in 1...13 {
            let item = NSMenuItem(title: "Cat \(i)", action: #selector(ctxPickCat(_:)), keyEquivalent: "")
            item.tag = i
            item.target = self
            if pet.catFolder == "Cat \(i)" { item.state = .on }
            catSub.addItem(item)
        }
        let catItem = NSMenuItem(title: "Choose Cat", action: nil, keyEquivalent: "")
        catItem.submenu = catSub
        menu.addItem(catItem)

        // Color Variant
        let catDir = "\(Config.packPath)/\(pet.catFolder)"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: catDir) {
            let variants = contents.filter { name in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: "\(catDir)/\(name)", isDirectory: &isDir)
                return isDir.boolValue
            }.sorted()
            if variants.count > 1 {
                let varSub = NSMenu()
                for v in variants {
                    let item = NSMenuItem(title: v, action: #selector(ctxPickVariant(_:)), keyEquivalent: "")
                    item.representedObject = v
                    item.target = self
                    if v == pet.catVariant { item.state = .on }
                    varSub.addItem(item)
                }
                let varItem = NSMenuItem(title: "Color Variant", action: nil, keyEquivalent: "")
                varItem.submenu = varSub
                menu.addItem(varItem)
            }
        }

        if pets.count > 1 {
            menu.addItem(.separator())
            let rm = NSMenuItem(title: "Remove This Cat", action: #selector(ctxRemovePet), keyEquivalent: "")
            rm.target = self
            menu.addItem(rm)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))

        NSMenu.popUpContextMenu(menu, with: event, for: pet.view)
    }

    @objc func ctxPickCat(_ sender: NSMenuItem) {
        guard let pet = menuTargetPet else { return }
        let folder = "Cat \(sender.tag)"
        pet.changeCat(folder: folder, variant: findFirstVariant(folder: folder))
    }

    @objc func ctxPickVariant(_ sender: NSMenuItem) {
        guard let pet = menuTargetPet, let v = sender.representedObject as? String else { return }
        pet.changeCat(folder: pet.catFolder, variant: v)
    }

    @objc func ctxRemovePet() {
        guard let pet = menuTargetPet, pets.count > 1,
              let idx = pets.firstIndex(where: { $0 === pet }) else { return }
        pets.remove(at: idx)
        pet.close()
    }

    // MARK: - Pet Management

    func addPet(catFolder: String, catVariant: String) {
        let startX = screenBounds.minX + CGFloat.random(in: 50...(max(51, screenBounds.width - 150)))
        let pet = PetInstance(
            catFolder: catFolder, catVariant: catVariant,
            startX: startX, bottomY: screenBounds.minY
        )
        guard !pet.brain.anims.isEmpty else { pet.close(); return }
        pets.append(pet)
    }

    func findFirstVariant(folder: String) -> String {
        let catDir = "\(Config.packPath)/\(folder)"
        if let items = try? FileManager.default.contentsOfDirectory(atPath: catDir) {
            let dirs = items.filter { name in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: "\(catDir)/\(name)", isDirectory: &isDir)
                return isDir.boolValue
            }.sorted()
            if let first = dirs.first { return first }
        }
        return folder
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if menu == statusItem.menu { rebuildStatusMenu() }
    }
}

// ============================================================================
// MARK: - Main
// ============================================================================

if CommandLine.arguments.count > 1 {
    Config.packPath = CommandLine.arguments[1]
} else {
    let execDir = (CommandLine.arguments[0] as NSString).deletingLastPathComponent
    let candidate = execDir + "/Kittens pack"
    Config.packPath = FileManager.default.fileExists(atPath: candidate)
        ? candidate
        : NSHomeDirectory() + "/Downloads/Kittens pack"
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
