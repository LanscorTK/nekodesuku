import Cocoa
import ImageIO
import ServiceManagement

// ============================================================================
// MARK: - Configuration
// ============================================================================

struct Config {
    static var packPath = ""
    static var scale: CGFloat = 6.0
    static var walkSpeed: CGFloat = 30
    static var gravitySpeed: CGFloat = 80
    static var activityLevel: Double = 1.0  // 0.0=calm, 1.0=normal, 2.0=hyperactive
    static var windowSize: CGFloat { 16.0 * scale }

    static func save() {
        let d = UserDefaults.standard
        d.set(Double(scale), forKey: "cfg_scale")
        d.set(Double(walkSpeed), forKey: "cfg_walkSpeed")
        d.set(Double(gravitySpeed), forKey: "cfg_gravity")
        d.set(activityLevel, forKey: "cfg_activity")
    }

    static func restore() {
        let d = UserDefaults.standard
        if d.object(forKey: "cfg_scale") != nil {
            scale = CGFloat(d.double(forKey: "cfg_scale"))
            walkSpeed = CGFloat(d.double(forKey: "cfg_walkSpeed"))
            gravitySpeed = CGFloat(d.double(forKey: "cfg_gravity"))
            activityLevel = d.double(forKey: "cfg_activity")
        }
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
    case clickReact, petting
    case followMouse, pawAttack
    case zoomies, chaseBug, stretch
    case climbEdge, walkTop
}

struct Movement {
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    var breathOffset: CGFloat = 0
}

class PetBrain {
    var state: PetState = .sitIdle
    var stateTime: TimeInterval = 0
    var stateDuration: TimeInterval = 4
    var facingRight = true
    var walkSpeed: CGFloat { Config.walkSpeed }
    var transitionDelay: TimeInterval = 0

    // Mouse follow
    var mousePos: NSPoint = .zero
    var petPos: NSPoint = .zero
    var screenMaxY: CGFloat = 0
    var followDirTime: TimeInterval = 0
    var followDir: String = "right"

    // Compound event tracking
    var eventPhase: Int = 0
    var eventCounter: Int = 0
    var eventTarget: NSPoint = .zero
    var eventMaxFlips: Int = 0

    var anims: [String: Animation] = [:]
    var currentAnim: Animation?

    static let dir8 = ["right", "left", "up", "down",
                       "right_up", "right_d", "left_up", "left_d"]

    static func direction8(dx: CGFloat, dy: CGFloat) -> String {
        let deg = atan2(dy, dx) * 180.0 / .pi
        let nd = deg < 0 ? deg + 360 : deg
        switch nd {
        case   0..<22.5:  return "right"
        case  22.5..<67.5: return "right_up"
        case  67.5..<112.5: return "up"
        case 112.5..<157.5: return "left_up"
        case 157.5..<202.5: return "left"
        case 202.5..<247.5: return "left_d"
        case 247.5..<292.5: return "down"
        case 292.5..<337.5: return "right_d"
        default:           return "right"
        }
    }

    func loadAnims(catPath: String) {
        var map: [(String, String)] = [
            ("walk_r",      "walk_right.gif"),
            ("walk_l",      "walk_left.gif"),
            ("sleep_r",     "sleep1(r).gif"),
            ("sleep_l",     "sleep1(l).gif"),
            ("meow",        "meow_sit.gif"),
            ("yawn",        "yawn_sit.gif"),
            ("wash",        "wash_sit.gif"),
            ("scratch_r",   "scratch(r).gif"),
            ("scratch_l",   "scratch(l).gif"),
            ("hiss_r",      "hiss(r).gif"),
            ("hiss_l",      "hiss(l).gif"),
            ("meow_stand",  "meow_stand.gif"),
            ("on_hind_legs","on_hind_legs.gif"),
            ("wash_lie",    "wash_lie.gif"),
            ("yawn_stand",  "yawn_stand.gif"),
        ]
        for dir in PetBrain.dir8 {
            map.append(("walk_\(dir)",    "walk_\(dir).gif"))
            map.append(("paw_att_\(dir)", "paw_att_\(dir).gif"))
            map.append(("eat_\(dir)",     "eat_\(dir).gif"))
        }

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
        case .clickReact, .petting:
            break // anim set by trigger methods
        case .followMouse:
            stateDuration = 5.0
            followDirTime = 10 // force immediate direction calc
        case .pawAttack:
            stateDuration = 99
            setAnim("paw_att_\(followDir)")
        case .zoomies:
            eventPhase = 0; eventCounter = 0
            eventMaxFlips = Int.random(in: 6...8)
            facingRight = Bool.random()
            stateDuration = 99
            setAnim(facingRight ? "walk_r" : "walk_l")
        case .chaseBug:
            eventPhase = 0
            let ox = CGFloat.random(in: -200...200)
            let oy = CGFloat.random(in: -100...100)
            eventTarget = NSPoint(x: petPos.x + ox, y: petPos.y + oy)
            stateDuration = .random(in: 2...3)
            let dir = PetBrain.direction8(dx: eventTarget.x - petPos.x,
                                          dy: eventTarget.y - petPos.y)
            followDir = dir
            setAnim("walk_\(dir)")
        case .stretch:
            eventPhase = 0
            stateDuration = 99
            setAnim("on_hind_legs")
        case .climbEdge:
            stateDuration = 99  // transition triggered by position
            setAnim("walk_up")
        case .walkTop:
            stateDuration = .random(in: 3...7)
            facingRight = Bool.random()
            setAnim(facingRight ? "walk_r" : "walk_l")
        }
    }

    func setAnimPublic(_ key: String) { setAnim(key) }

    private func setAnim(_ key: String) {
        if let a = anims[key] { a.reset(); currentAnim = a; return }
        let fb = key.replacingOccurrences(of: "_l", with: "_r")
        if let a = anims[fb] { a.reset(); currentAnim = a; return }
        // Directional fallbacks
        if key.hasPrefix("walk_") {
            if let a = anims["walk_r"] ?? anims["walk_right"] { a.reset(); currentAnim = a; return }
        }
        if key.hasPrefix("paw_att_") {
            for d in PetBrain.dir8 { if let a = anims["paw_att_\(d)"] { a.reset(); currentAnim = a; return } }
            if let a = anims["scratch_r"] ?? anims["scratch_l"] { a.reset(); currentAnim = a; return }
        }
        if key.hasPrefix("eat_") {
            for d in PetBrain.dir8 { if let a = anims["eat_\(d)"] { a.reset(); currentAnim = a; return } }
            if let a = anims["meow"] { a.reset(); currentAnim = a; return }
        }
        if key == "on_hind_legs" || key == "yawn_stand" {
            if let a = anims["yawn"] ?? anims["meow"] { a.reset(); currentAnim = a; return }
        }
    }

    // MARK: Click & Petting

    func triggerClickReact() {
        let r = Double.random(in: 0...1)
        if r < 0.5 { setAnim("meow_stand") }
        else if r < 0.8 { setAnim(facingRight ? "hiss_r" : "hiss_l") }
        else { setAnim("on_hind_legs") }
        state = .clickReact; stateTime = 0; stateDuration = 99; transitionDelay = 0
    }

    func triggerPetting() {
        setAnim("wash_lie")
        state = .petting; stateTime = 0; stateDuration = 99999; transitionDelay = 0
    }

    func stopPetting() { enter(.yawning) }

    // MARK: Update

    func update(dt: TimeInterval) -> Movement {
        stateTime += dt
        var move = Movement()

        if transitionDelay > 0 {
            transitionDelay -= dt
        } else if case .sitIdle = state {
            // no frame advance in idle
        } else {
            currentAnim?.advance(by: dt)
        }

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
        case .meowing, .yawning, .washing, .scratching, .clickReact:
            if currentAnim?.completedOnce == true { enter(.sitIdle) }
        case .petting:
            break
        case .followMouse:
            followDirTime += dt
            if followDirTime >= 0.5 {
                followDirTime = 0
                followDir = PetBrain.direction8(dx: mousePos.x - petPos.x,
                                                dy: mousePos.y - petPos.y)
                setAnim("walk_\(followDir)")
            }
            let mdx = mousePos.x - petPos.x
            let mdy = mousePos.y - petPos.y
            let dist = hypot(mdx, mdy)
            if dist > 1 {
                let spd = walkSpeed * CGFloat(dt)
                move.dx = (mdx / dist) * spd
                move.dy = (mdy / dist) * spd
            }
            if dist < 50 || stateTime >= stateDuration { enter(.pawAttack) }
        case .pawAttack:
            if currentAnim?.completedOnce == true { enter(.sitIdle) }
        case .zoomies:
            let spd = walkSpeed * 2.0 * CGFloat(dt)
            move.dx = facingRight ? spd : -spd
            if stateTime >= 0.8 {
                stateTime = 0; eventCounter += 1
                facingRight = !facingRight
                setAnim(facingRight ? "walk_r" : "walk_l")
                if eventCounter >= eventMaxFlips { enter(.sitIdle) }
            }
        case .chaseBug:
            switch eventPhase {
            case 0:
                let ddx = eventTarget.x - petPos.x
                let ddy = eventTarget.y - petPos.y
                let dist = hypot(ddx, ddy)
                if dist > 2 {
                    let spd = walkSpeed * CGFloat(dt)
                    move.dx = (ddx / dist) * spd
                    move.dy = (ddy / dist) * spd
                }
                if dist < 20 || stateTime >= stateDuration {
                    eventPhase = 1; stateTime = 0; stateDuration = 99
                    setAnim("paw_att_\(followDir)")
                }
            case 1:
                if currentAnim?.completedOnce == true {
                    eventPhase = 2; stateTime = 0
                    setAnim("eat_\(followDir)")
                }
            default:
                if currentAnim?.completedOnce == true { enter(.sitIdle) }
            }
        case .stretch:
            switch eventPhase {
            case 0:
                if currentAnim?.completedOnce == true {
                    eventPhase = 1; stateTime = 0
                    setAnim("yawn_stand")
                }
            default:
                if currentAnim?.completedOnce == true { enter(.sitIdle) }
            }
        case .climbEdge:
            if transitionDelay <= 0 {
                move.dy = walkSpeed * CGFloat(dt)
            }
            if petPos.y >= screenMaxY - Config.windowSize / 2 {
                enter(.walkTop)
            }
        case .walkTop:
            if transitionDelay <= 0 {
                move.dx = facingRight ? walkSpeed * CGFloat(dt) : -walkSpeed * CGFloat(dt)
            }
            if stateTime >= stateDuration { enter(.sitIdle) }
        }
        return move
    }

    var image: NSImage? {
        if case .sitIdle = state { return currentAnim?.firstImage }
        return currentAnim?.currentImage
    }

    private func pickNext() {
        let a = Config.activityLevel
        let r = Double.random(in: 0...1)
        // Active behaviors scale with activityLevel; calm behaviors fill the rest
        let followChance = 0.20 * a
        let zoomChance   = 0.05 * a
        let chaseChance  = 0.05 * a
        let stretchChance = 0.05 * a
        var t = 0.0
        t += followChance;  if r < t { enter(.followMouse); return }
        t += zoomChance;    if r < t { enter(.zoomies); return }
        t += chaseChance;   if r < t { enter(.chaseBug); return }
        t += stretchChance; if r < t { enter(.stretch); return }
        // Remaining probability spread across calm behaviors
        let calm = 1.0 - t
        t += calm * 0.23; if r < t { enter(.walkRight); return }
        t += calm * 0.23; if r < t { enter(.walkLeft); return }
        t += calm * 0.15; if r < t { enter(.sleeping); return }
        t += calm * 0.13; if r < t { enter(.meowing); return }
        t += calm * 0.10; if r < t { enter(.yawning); return }
        t += calm * 0.10; if r < t { enter(.washing); return }
        enter(.scratching)
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
    var wasDragged = false
    var mouseDownTime: TimeInterval = 0
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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with e: NSEvent) { instance?.showNameTag() }
    override func mouseExited(with e: NSEvent) { instance?.hideNameTag() }

    override func mouseDown(with e: NSEvent) {
        isDragging = true
        wasDragged = false
        mouseDownTime = ProcessInfo.processInfo.systemUptime
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
        if !wasDragged {
            if hypot(s.x - mouseDownPos.x, s.y - mouseDownPos.y) > 3 {
                wasDragged = true
                gravityEnabled = true
            }
        }
        w.setFrameOrigin(NSPoint(x: s.x - dragOffset.x, y: s.y - dragOffset.y))
    }

    override func mouseUp(with e: NSEvent) {
        if !wasDragged {
            gravityEnabled = false
            if case .petting = instance?.brain.state {
                instance?.brain.stopPetting()
            } else {
                instance?.brain.triggerClickReact()
            }
        }
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
    var petName: String
    var lastTick: TimeInterval
    var nameWindow: NSWindow?

    var catPath: String { "\(Config.packPath)/\(catFolder)/\(catVariant)" }

    init(catFolder: String, catVariant: String, petName: String? = nil, startX: CGFloat, bottomY: CGFloat) {
        self.catFolder = catFolder
        self.catVariant = catVariant
        self.petName = petName ?? catVariant
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

    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastTick
        lastTick = now

        // Detect long press → petting
        if view.isDragging && !view.wasDragged {
            if case .petting = brain.state { }
            else if (now - view.mouseDownTime) > 1.0 {
                brain.triggerPetting()
            }
        }

        // Detect which screen this pet is on
        let petCenter = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let screenBounds = (NSScreen.screens.first { $0.frame.contains(petCenter) }
                            ?? NSScreen.main)?.visibleFrame ?? .zero

        // Feed positions to brain
        brain.mousePos = NSEvent.mouseLocation
        brain.petPos = NSPoint(x: window.frame.origin.x + Config.windowSize / 2,
                               y: window.frame.origin.y + Config.windowSize / 2)
        brain.screenMaxY = screenBounds.maxY

        let move = brain.update(dt: dt)

        if !view.isDragging {
            var origin = window.frame.origin

            // Gravity (disabled during airborne states or when caught)
            let bottomY = screenBounds.minY
            let noGravityState: Bool = {
                switch brain.state {
                case .followMouse, .chaseBug, .climbEdge, .walkTop: return true
                default: return false
                }
            }()
            if view.gravityEnabled && !noGravityState && origin.y > bottomY + 2 {
                origin.y = max(bottomY, origin.y - Config.gravitySpeed * CGFloat(dt))
            }

            // Apply movement
            origin.x += move.dx
            origin.y += move.dy

            // Clamp to total screen area (union of all screens)
            let totalBounds = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }
            let minX = totalBounds.minX
            let maxX = totalBounds.maxX - Config.windowSize
            let minY = screenBounds.minY  // vertical: use current screen
            let maxY = screenBounds.maxY - Config.windowSize
            if origin.x <= minX { origin.x = minX }
            if origin.x >= maxX { origin.x = maxX }
            if origin.y < minY { origin.y = minY }
            if origin.y > maxY { origin.y = maxY }

            // Edge climbing: lock position to edge
            if case .climbEdge = brain.state {
                origin.x = brain.facingRight ? maxX : minX
            }
            if case .walkTop = brain.state {
                origin.y = maxY
                // Bounce at screen edges while on top
                if origin.x <= minX { brain.facingRight = true; brain.setAnimPublic(brain.facingRight ? "walk_r" : "walk_l") }
                if origin.x >= maxX { brain.facingRight = false; brain.setAnimPublic(brain.facingRight ? "walk_r" : "walk_l") }
            }

            // Edge bounce / climb trigger
            if case .walkLeft = brain.state, origin.x <= minX {
                if Double.random(in: 0...1) < 0.2 {
                    brain.facingRight = false
                    brain.enter(.climbEdge)
                } else {
                    brain.enter(.walkRight)
                }
            }
            if case .walkRight = brain.state, origin.x >= maxX {
                if Double.random(in: 0...1) < 0.2 {
                    brain.facingRight = true
                    brain.enter(.climbEdge)
                } else {
                    brain.enter(.walkLeft)
                }
            }

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

    func showNameTag() {
        guard nameWindow == nil else { return }
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (petName as NSString).size(withAttributes: attrs)
        let padding: CGFloat = 8
        let w = textSize.width + padding * 2
        let h: CGFloat = 20

        let petFrame = window.frame
        let x = petFrame.midX - w / 2
        let y = petFrame.maxY + 4

        let nw = NSWindow(contentRect: NSRect(x: x, y: y, width: w, height: h),
                          styleMask: .borderless, backing: .buffered, defer: false)
        nw.isOpaque = false
        nw.backgroundColor = .clear
        nw.level = .floating
        nw.collectionBehavior = [.canJoinAllSpaces, .stationary]
        nw.ignoresMouseEvents = true

        let label = NSTextField(labelWithString: petName)
        label.font = font
        label.textColor = .white
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 0, width: w, height: h)
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor(white: 0, alpha: 0.7).cgColor
        label.layer?.cornerRadius = 4
        nw.contentView = label
        nw.orderFront(nil)
        nameWindow = nw
    }

    func hideNameTag() {
        nameWindow?.orderOut(nil)
        nameWindow = nil
    }

    func close() {
        hideNameTag()
        window.orderOut(nil)
    }
}

// ============================================================================
// MARK: - Settings Window
// ============================================================================

class SettingsWindowController {
    var window: NSWindow?
    weak var appDelegate: AppDelegate?

    func show() {
        if let w = window { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 260),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Settings"
        w.center()
        w.isReleasedWhenClosed = false

        let view = NSView(frame: w.contentView!.bounds)
        var y: CGFloat = 220

        func addSlider(label: String, min: Double, max: Double, value: Double,
                       action: Selector) -> NSSlider {
            let lbl = NSTextField(labelWithString: label)
            lbl.frame = NSRect(x: 20, y: y, width: 120, height: 20)
            view.addSubview(lbl)

            let valLabel = NSTextField(labelWithString: String(format: "%.0f", value))
            valLabel.frame = NSRect(x: 270, y: y, width: 40, height: 20)
            valLabel.alignment = .right
            valLabel.tag = 1000 + Int(y)
            view.addSubview(valLabel)

            let slider = NSSlider(value: value, minValue: min, maxValue: max,
                                  target: self, action: action)
            slider.frame = NSRect(x: 130, y: y, width: 135, height: 20)
            slider.tag = Int(y)
            view.addSubview(slider)
            y -= 45
            return slider
        }

        let _ = addSlider(label: "Size (scale)", min: 3, max: 10,
                          value: Double(Config.scale), action: #selector(scaleChanged(_:)))
        let _ = addSlider(label: "Walk Speed", min: 10, max: 80,
                          value: Double(Config.walkSpeed), action: #selector(speedChanged(_:)))
        let _ = addSlider(label: "Gravity", min: 20, max: 200,
                          value: Double(Config.gravitySpeed), action: #selector(gravityChanged(_:)))
        let _ = addSlider(label: "Activity", min: 0, max: 2,
                          value: Config.activityLevel, action: #selector(activityChanged(_:)))

        // Activity labels
        let calmLabel = NSTextField(labelWithString: "calm")
        calmLabel.frame = NSRect(x: 130, y: y + 20, width: 40, height: 16)
        calmLabel.font = NSFont.systemFont(ofSize: 9)
        calmLabel.textColor = .secondaryLabelColor
        view.addSubview(calmLabel)
        let hyperLabel = NSTextField(labelWithString: "hyper")
        hyperLabel.frame = NSRect(x: 230, y: y + 20, width: 40, height: 16)
        hyperLabel.font = NSFont.systemFont(ofSize: 9)
        hyperLabel.textColor = .secondaryLabelColor
        view.addSubview(hyperLabel)

        y -= 5
        let resetBtn = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults(_:)))
        resetBtn.frame = NSRect(x: 20, y: y, width: 140, height: 30)
        view.addSubview(resetBtn)

        w.contentView = view
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }

    private func updateValueLabel(slider: NSSlider, format: String = "%.0f") {
        guard let view = slider.superview else { return }
        let tag = 1000 + slider.tag
        if let label = view.viewWithTag(tag) as? NSTextField {
            label.stringValue = String(format: format, slider.doubleValue)
        }
    }

    @objc func scaleChanged(_ sender: NSSlider) {
        updateValueLabel(slider: sender)
        Config.scale = CGFloat(sender.doubleValue)
        Config.save()
        appDelegate?.resizeAllPets()
    }

    @objc func speedChanged(_ sender: NSSlider) {
        updateValueLabel(slider: sender)
        Config.walkSpeed = CGFloat(sender.doubleValue)
        Config.save()
    }

    @objc func gravityChanged(_ sender: NSSlider) {
        updateValueLabel(slider: sender)
        Config.gravitySpeed = CGFloat(sender.doubleValue)
        Config.save()
    }

    @objc func activityChanged(_ sender: NSSlider) {
        updateValueLabel(slider: sender, format: "%.1f")
        Config.activityLevel = sender.doubleValue
        Config.save()
    }

    @objc func resetDefaults(_ sender: Any) {
        Config.scale = 6.0
        Config.walkSpeed = 30
        Config.gravitySpeed = 80
        Config.activityLevel = 1.0
        Config.save()
        appDelegate?.resizeAllPets()
        // Reopen to refresh sliders
        window?.close()
        window = nil
        show()
    }
}

// ============================================================================
// MARK: - App Delegate
// ============================================================================

class AppDelegate: NSObject, NSApplicationDelegate {
    var pets: [PetInstance] = []
    var timer: Timer!
    var statusItem: NSStatusItem!
    var menuTargetPet: PetInstance?
    let settingsController = SettingsWindowController()

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard NSScreen.main != nil else {
            print("No screen found"); NSApp.terminate(nil); return
        }

        Config.restore()
        settingsController.appDelegate = self
        restorePets()

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
        for pet in pets { pet.tick() }
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
            let title = "Cat #\(i + 1): \(pet.petName)"
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

        if Bundle.main.bundlePath.hasSuffix(".app") {
            let loginItem = NSMenuItem(title: "Launch at Login",
                                       action: #selector(toggleLaunchAtLogin),
                                       keyEquivalent: "")
            loginItem.target = self
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(loginItem)
        }

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let versionItem = NSMenuItem(title: "NekoDeskuToppu v\(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
    }

    @objc func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }

    @objc func checkForUpdates() {
        let repoURL = "https://api.github.com/repos/lanscortk/nekodesuku/releases/latest"
        guard let url = URL(string: repoURL) else { return }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    let alert = NSAlert()
                    alert.messageText = "Update Check Failed"
                    alert.informativeText = "Could not reach GitHub. Check your internet connection."
                    alert.runModal()
                    return
                }
                let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                let local = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
                if remote.compare(local, options: .numeric) == .orderedDescending {
                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "Version \(remote) is available (you have \(local))."
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Later")
                    if alert.runModal() == .alertFirstButtonReturn,
                       let htmlURL = json["html_url"] as? String,
                       let dl = URL(string: htmlURL) {
                        NSWorkspace.shared.open(dl)
                    }
                } else {
                    let alert = NSAlert()
                    alert.messageText = "You're Up to Date"
                    alert.informativeText = "NekoDeskuToppu \(local) is the latest version."
                    alert.runModal()
                }
            }
        }.resume()
    }

    @objc func addRandomPet() {
        let catNum = Int.random(in: 1...13)
        let folder = "Cat \(catNum)"
        addPet(catFolder: folder, catVariant: findFirstVariant(folder: folder))
        savePets()
    }

    @objc func removeLastPet() {
        guard pets.count > 1 else { return }
        pets.removeLast().close()
        savePets()
    }

    @objc func statusChangeCat(_ sender: NSMenuItem) {
        let petIdx = sender.tag / 100
        let catNum = sender.tag % 100
        guard petIdx < pets.count else { return }
        let folder = "Cat \(catNum)"
        pets[petIdx].changeCat(folder: folder, variant: findFirstVariant(folder: folder))
        savePets()
    }

    // MARK: - Per-Pet Context Menu

    func showPetMenu(for pet: PetInstance, event: NSEvent) {
        menuTargetPet = pet
        let menu = NSMenu()

        let catSub = NSMenu()
        for i in 1...13 {
            let item = NSMenuItem(title: "Cat \(i)", action: #selector(ctxPickCat(_:)), keyEquivalent: "")
            item.tag = i; item.target = self
            if pet.catFolder == "Cat \(i)" { item.state = .on }
            catSub.addItem(item)
        }
        let catItem = NSMenuItem(title: "Choose Cat", action: nil, keyEquivalent: "")
        catItem.submenu = catSub
        menu.addItem(catItem)

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
                    item.representedObject = v; item.target = self
                    if v == pet.catVariant { item.state = .on }
                    varSub.addItem(item)
                }
                let varItem = NSMenuItem(title: "Color Variant", action: nil, keyEquivalent: "")
                varItem.submenu = varSub
                menu.addItem(varItem)
            }
        }

        menu.addItem(.separator())
        let renameItem = NSMenuItem(title: "Rename…", action: #selector(ctxRenamePet), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

        if pets.count > 1 {
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
        savePets()
    }

    @objc func ctxPickVariant(_ sender: NSMenuItem) {
        guard let pet = menuTargetPet, let v = sender.representedObject as? String else { return }
        pet.changeCat(folder: pet.catFolder, variant: v)
        savePets()
    }

    @objc func ctxRenamePet() {
        guard let pet = menuTargetPet else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Cat"
        alert.informativeText = "Enter a new name:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = pet.petName
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        if alert.runModal() == .alertFirstButtonReturn {
            let name = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                pet.petName = name
                savePets()
            }
        }
    }

    @objc func ctxRemovePet() {
        guard let pet = menuTargetPet, pets.count > 1,
              let idx = pets.firstIndex(where: { $0 === pet }) else { return }
        pets.remove(at: idx)
        pet.close()
        savePets()
    }

    // MARK: - Settings

    @objc func openSettings() {
        settingsController.show()
    }

    func resizeAllPets() {
        let sz = Config.windowSize
        for pet in pets {
            let origin = pet.window.frame.origin
            pet.window.setFrame(NSRect(x: origin.x, y: origin.y, width: sz, height: sz), display: false)
            pet.view.frame = NSRect(x: 0, y: 0, width: sz, height: sz)
            pet.view.updateTrackingAreas()
            pet.brain.loadAnims(catPath: pet.catPath)
            pet.brain.enter(.sitIdle)
        }
    }

    // MARK: - Persistence

    func savePets() {
        let data = pets.map { ["folder": $0.catFolder, "variant": $0.catVariant, "name": $0.petName] }
        UserDefaults.standard.set(data, forKey: "savedPets")
    }

    func restorePets() {
        if let saved = UserDefaults.standard.array(forKey: "savedPets") as? [[String: String]], !saved.isEmpty {
            for entry in saved {
                let folder = entry["folder"] ?? "Cat 1"
                let variant = entry["variant"] ?? folder
                let name = entry["name"]
                addPet(catFolder: folder, catVariant: variant, petName: name)
            }
        }
        // Fall back to default if nothing loaded (first launch or stale saved data)
        if pets.isEmpty {
            addPet(catFolder: "Cat 1", catVariant: "Cat 1")
        }
    }

    // MARK: - Pet Management

    func addPet(catFolder: String, catVariant: String, petName: String? = nil) {
        let mouseScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main ?? NSScreen.screens.first!
        let sb = mouseScreen.visibleFrame
        let startX = sb.minX + CGFloat.random(in: 50...(max(51, sb.width - 150)))
        let pet = PetInstance(
            catFolder: catFolder, catVariant: catVariant, petName: petName,
            startX: startX, bottomY: sb.minY
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
