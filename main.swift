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

    var catPath: String {
        if catVariant.isEmpty { return "\(Config.packPath)/\(catFolder)" }
        return "\(Config.packPath)/\(catFolder)/\(catVariant)"
    }

    init(catFolder: String, catVariant: String, petName: String? = nil, startX: CGFloat, bottomY: CGFloat) {
        self.catFolder = catFolder
        self.catVariant = catVariant
        self.petName = petName ?? Config.catDisplayName(catFolder)
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
// MARK: - Main Panel
// ============================================================================

func extractThumbnail(gifPath: String, size: CGFloat) -> NSImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: gifPath) as CFURL, nil),
          CGImageSourceGetCount(src) > 0,
          let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    let px = Int(size * 2)
    guard let ctx = CGContext(
        data: nil, width: px, height: px,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .none
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: px, height: px))
    guard let scaled = ctx.makeImage() else { return nil }
    return NSImage(cgImage: scaled, size: NSSize(width: size, height: size))
}

func gifPathForCat(folder: String, variant: String) -> String {
    let catDir = "\(Config.packPath)/\(folder)"
    if variant.isEmpty {
        return "\(catDir)/meow_sit.gif"
    }
    return "\(catDir)/\(variant)/meow_sit.gif"
}

class MainPanelController {
    var window: NSWindow?
    weak var appDelegate: AppDelegate?
    var catListView: NSView?
    var rightHeaderLabel: NSTextField?
    var variantView: NSView?         // area below grid for variant buttons
    var selectedPetIndex: Int? = nil  // nil = add mode, Int = change breed mode
    var pendingFolder: String? = nil  // breed clicked that has variants

    let winW: CGFloat = 560
    let winH: CGFloat = 500
    let leftW: CGFloat = 255
    let topH: CGFloat = 290  // height of cat area (above settings)

    func show() {
        if let w = window {
            rebuildCatList()
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: winW, height: winH),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "NekoDeskuToppu"
        w.center()
        w.isReleasedWhenClosed = false

        let root = NSView(frame: w.contentView!.bounds)

        // === Left column: My Cats ===
        let leftHeader = NSTextField(labelWithString: "My Cats")
        leftHeader.font = NSFont.boldSystemFont(ofSize: 14)
        leftHeader.frame = NSRect(x: 16, y: winH - 32, width: 200, height: 20)
        root.addSubview(leftHeader)

        let scrollH: CGFloat = topH - 80
        let catScroll = NSScrollView(frame: NSRect(x: 10, y: winH - 32 - scrollH - 8, width: leftW - 15, height: scrollH))
        catScroll.hasVerticalScroller = true
        catScroll.drawsBackground = false
        catScroll.autohidesScrollers = true
        let catContent = NSView(frame: NSRect(x: 0, y: 0, width: leftW - 30, height: scrollH))
        catScroll.documentView = catContent
        root.addSubview(catScroll)
        catListView = catContent

        let btnY = winH - topH - 4
        let addRandBtn = NSButton(title: "+ Random", target: self, action: #selector(addRandomCat))
        addRandBtn.frame = NSRect(x: 16, y: btnY, width: 80, height: 28)
        addRandBtn.font = NSFont.systemFont(ofSize: 11)
        root.addSubview(addRandBtn)

        let summonBtn = NSButton(title: "Summon", target: self, action: #selector(summonAll))
        summonBtn.frame = NSRect(x: 100, y: btnY, width: 70, height: 28)
        summonBtn.font = NSFont.systemFont(ofSize: 11)
        root.addSubview(summonBtn)

        let removeAllBtn = NSButton(title: "Rm All", target: self, action: #selector(removeAllCats))
        removeAllBtn.frame = NSRect(x: 174, y: btnY, width: 62, height: 28)
        removeAllBtn.font = NSFont.systemFont(ofSize: 11)
        root.addSubview(removeAllBtn)

        // === Vertical divider ===
        let vDiv = NSBox(frame: NSRect(x: leftW, y: winH - topH, width: 1, height: topH - 10))
        vDiv.boxType = .separator
        root.addSubview(vDiv)

        // === Right column: Add a Cat / Change Breed ===
        let rHeader = NSTextField(labelWithString: "Add a Cat")
        rHeader.font = NSFont.boldSystemFont(ofSize: 14)
        rHeader.frame = NSRect(x: leftW + 16, y: winH - 32, width: 260, height: 20)
        root.addSubview(rHeader)
        rightHeaderLabel = rHeader

        buildCatGrid(in: root)

        // === Variant picker area (below grid, right column) ===
        let varArea = NSView(frame: NSRect(x: leftW + 10, y: winH - topH + 5, width: winW - leftW - 20, height: 50))
        root.addSubview(varArea)
        variantView = varArea

        // === Horizontal divider ===
        let hDiv = NSBox(frame: NSRect(x: 10, y: winH - topH - 10, width: winW - 20, height: 1))
        hDiv.boxType = .separator
        root.addSubview(hDiv)

        // === Bottom: Settings ===
        let sHeader = NSTextField(labelWithString: "Settings")
        sHeader.font = NSFont.boldSystemFont(ofSize: 14)
        sHeader.frame = NSRect(x: 16, y: winH - topH - 36, width: 200, height: 20)
        root.addSubview(sHeader)

        buildSettings(in: root, baseY: winH - topH - 65)

        w.contentView = root
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w

        rebuildCatList()
    }

    // MARK: Cat List

    func rebuildCatList() {
        guard let container = catListView else { return }
        container.subviews.removeAll()

        guard let pets = appDelegate?.pets else { return }
        let rowH: CGFloat = 72
        let contentW = container.enclosingScrollView?.frame.width ?? 240
        let totalH = max(CGFloat(pets.count) * rowH, container.enclosingScrollView?.frame.height ?? 200)
        container.frame = NSRect(x: 0, y: 0, width: contentW, height: totalH)

        for (i, pet) in pets.enumerated() {
            let y = totalH - CGFloat(i + 1) * rowH
            let row = NSView(frame: NSRect(x: 0, y: y, width: contentW, height: rowH))
            row.wantsLayer = true

            // Selected highlight
            if selectedPetIndex == i {
                row.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
                row.layer?.cornerRadius = 6
            }

            // Click to select/deselect
            let clickBtn = NSButton(frame: NSRect(x: 0, y: 0, width: contentW, height: rowH))
            clickBtn.isBordered = false
            clickBtn.isTransparent = true
            clickBtn.tag = i
            clickBtn.target = self
            clickBtn.action = #selector(selectCat(_:))
            row.addSubview(clickBtn)

            // Thumbnail (vertically centered)
            let thumbSize: CGFloat = 40
            let thumbY = (rowH - thumbSize) / 2
            let gifPath = gifPathForCat(folder: pet.catFolder, variant: pet.catVariant)
            if let thumb = extractThumbnail(gifPath: gifPath, size: thumbSize) {
                let iv = NSImageView(frame: NSRect(x: 8, y: thumbY, width: thumbSize, height: thumbSize))
                iv.image = thumb
                iv.imageScaling = .scaleNone
                row.addSubview(iv)
            }

            // Name (vertically centered with breed)
            let textX: CGFloat = 56
            let name = NSTextField(labelWithString: pet.petName)
            name.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            name.frame = NSRect(x: textX, y: 36, width: 120, height: 18)
            row.addSubview(name)

            // Breed
            let info = NSTextField(labelWithString: Config.catDisplayName(pet.catFolder))
            info.font = NSFont.systemFont(ofSize: 11)
            info.textColor = .secondaryLabelColor
            info.frame = NSRect(x: textX, y: 20, width: 120, height: 15)
            row.addSubview(info)

            // Buttons row
            let btnY: CGFloat = 2
            let renameBtn = NSButton(title: "Rename", target: self, action: #selector(renameCat(_:)))
            renameBtn.font = NSFont.systemFont(ofSize: 10)
            renameBtn.tag = i
            renameBtn.frame = NSRect(x: textX, y: btnY, width: 58, height: 18)
            renameBtn.bezelStyle = .inline
            row.addSubview(renameBtn)

            if pets.count > 1 {
                let delBtn = NSButton(title: "Del", target: self, action: #selector(removeCat(_:)))
                delBtn.font = NSFont.systemFont(ofSize: 10)
                delBtn.tag = i
                delBtn.frame = NSRect(x: textX + 62, y: btnY, width: 36, height: 18)
                delBtn.bezelStyle = .inline
                row.addSubview(delBtn)
            }

            // Top separator (between rows)
            if i > 0 {
                let sep = NSBox(frame: NSRect(x: 8, y: rowH - 1, width: contentW - 16, height: 1))
                sep.boxType = .separator
                row.addSubview(sep)
            }

            container.addSubview(row)
        }

        updateRightHeader()
    }

    func updateRightHeader() {
        if let idx = selectedPetIndex, let pets = appDelegate?.pets, idx < pets.count {
            rightHeaderLabel?.stringValue = "Change Breed: \(pets[idx].petName)"
        } else {
            selectedPetIndex = nil
            rightHeaderLabel?.stringValue = "Add a Cat"
        }
    }

    // MARK: Cat Grid

    func buildCatGrid(in root: NSView) {
        let cols = 5
        let cellW: CGFloat = 54
        let cellH: CGFloat = 72
        let gridX: CGFloat = leftW + 14
        let gridTopY: CGFloat = winH - 85

        for c in 1...13 {
            let col = (c - 1) % cols
            let row = (c - 1) / cols
            let x = gridX + CGFloat(col) * cellW
            let y = gridTopY - CGFloat(row) * cellH

            let folder = "Cat \(c)"
            let catDir = "\(Config.packPath)/\(folder)"
            let gifPath: String
            if FileManager.default.fileExists(atPath: "\(catDir)/meow_sit.gif") {
                gifPath = "\(catDir)/meow_sit.gif"
            } else {
                let variant = appDelegate?.findFirstVariant(folder: folder) ?? ""
                gifPath = variant.isEmpty ? "\(catDir)/meow_sit.gif" : "\(catDir)/\(variant)/meow_sit.gif"
            }

            let btn = NSButton(frame: NSRect(x: x, y: y, width: 46, height: 46))
            btn.bezelStyle = .regularSquare
            btn.isBordered = true
            if let thumb = extractThumbnail(gifPath: gifPath, size: 38) {
                btn.image = thumb
                btn.imagePosition = .imageOnly
                btn.imageScaling = .scaleNone
            } else {
                btn.title = folder
            }
            btn.tag = c
            btn.target = self
            btn.action = #selector(gridCatClicked(_:))
            root.addSubview(btn)

            let label = NSTextField(labelWithString: Config.catDisplayName(folder))
            label.font = NSFont.systemFont(ofSize: 9)
            label.alignment = .center
            label.frame = NSRect(x: x - 4, y: y - 16, width: 54, height: 14)
            root.addSubview(label)
        }
    }

    // MARK: Settings

    func buildSettings(in root: NSView, baseY: CGFloat) {
        var y = baseY
        let sliders: [(String, Double, Double, Double, Selector, String)] = [
            ("Size",     3, 10,  Double(Config.scale),        #selector(scaleChanged(_:)),    "%.0f"),
            ("Speed",   10, 80,  Double(Config.walkSpeed),    #selector(speedChanged(_:)),    "%.0f"),
            ("Gravity", 20, 200, Double(Config.gravitySpeed), #selector(gravityChanged(_:)),  "%.0f"),
            ("Activity", 0, 2,   Config.activityLevel,        #selector(activityChanged(_:)), "%.1f"),
        ]

        for (label, min, max, val, action, fmt) in sliders {
            let lbl = NSTextField(labelWithString: label)
            lbl.frame = NSRect(x: 20, y: y, width: 65, height: 20)
            lbl.font = NSFont.systemFont(ofSize: 11)
            root.addSubview(lbl)

            let slider = NSSlider(value: val, minValue: min, maxValue: max,
                                  target: self, action: action)
            slider.frame = NSRect(x: 90, y: y, width: winW - 160, height: 20)
            slider.tag = Int(y)
            root.addSubview(slider)

            let valLbl = NSTextField(labelWithString: String(format: fmt, val))
            valLbl.frame = NSRect(x: winW - 60, y: y, width: 45, height: 20)
            valLbl.alignment = .right
            valLbl.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            valLbl.tag = 1000 + Int(y)
            root.addSubview(valLbl)

            y -= 28
        }

        let resetBtn = NSButton(title: "Reset Defaults", target: self, action: #selector(resetDefaults(_:)))
        resetBtn.frame = NSRect(x: winW - 130, y: y - 2, width: 110, height: 24)
        resetBtn.font = NSFont.systemFont(ofSize: 10)
        root.addSubview(resetBtn)
    }

    // MARK: Actions

    @objc func selectCat(_ sender: NSButton) {
        if selectedPetIndex == sender.tag {
            selectedPetIndex = nil  // deselect
        } else {
            selectedPetIndex = sender.tag
        }
        rebuildCatList()
    }

    @objc func gridCatClicked(_ sender: NSButton) {
        let folder = "Cat \(sender.tag)"

        // Check if this breed has variants
        let catDir = "\(Config.packPath)/\(folder)"
        let variants: [String] = {
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: catDir) else { return [] }
            return items.filter { name in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: "\(catDir)/\(name)", isDirectory: &isDir)
                return isDir.boolValue
            }.sorted()
        }()

        if variants.count > 1 {
            // Has variants — show variant picker
            pendingFolder = folder
            showVariants(folder: folder, variants: variants)
        } else {
            // No variants — directly add/change
            let variant = variants.first ?? ""
            applyBreedSelection(folder: folder, variant: variant)
        }
    }

    func showVariants(folder: String, variants: [String]) {
        guard let container = variantView else { return }
        container.subviews.removeAll()

        let scrollView = NSScrollView(frame: container.bounds)
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let cellW: CGFloat = 42
        let contentW = max(CGFloat(variants.count) * cellW + 8, scrollView.frame.width)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: contentW, height: 46))

        for (i, v) in variants.enumerated() {
            let x: CGFloat = 4 + CGFloat(i) * cellW
            let gifPath = gifPathForCat(folder: folder, variant: v)
            let btn = NSButton(frame: NSRect(x: x, y: 6, width: 36, height: 36))
            btn.bezelStyle = .regularSquare
            btn.isBordered = true
            if let thumb = extractThumbnail(gifPath: gifPath, size: 30) {
                btn.image = thumb
                btn.imagePosition = .imageOnly
                btn.imageScaling = .scaleNone
            } else {
                btn.title = String(v.suffix(3))
                btn.font = NSFont.systemFont(ofSize: 8)
            }
            btn.tag = i
            btn.target = self
            btn.action = #selector(variantClicked(_:))
            btn.toolTip = v
            content.addSubview(btn)
        }

        scrollView.documentView = content
        container.addSubview(scrollView)
    }

    @objc func variantClicked(_ sender: NSButton) {
        guard let folder = pendingFolder else { return }
        let catDir = "\(Config.packPath)/\(folder)"
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: catDir) else { return }
        let variants = items.filter { name in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: "\(catDir)/\(name)", isDirectory: &isDir)
            return isDir.boolValue
        }.sorted()
        guard sender.tag < variants.count else { return }
        applyBreedSelection(folder: folder, variant: variants[sender.tag])
    }

    func applyBreedSelection(folder: String, variant: String) {
        if let idx = selectedPetIndex, let pets = appDelegate?.pets, idx < pets.count {
            pets[idx].changeCat(folder: folder, variant: variant)
        } else {
            appDelegate?.addPet(catFolder: folder, catVariant: variant)
        }
        appDelegate?.savePets()
        pendingFolder = nil
        variantView?.subviews.removeAll()
        rebuildCatList()
    }

    @objc func renameCat(_ sender: NSButton) {
        guard let pets = appDelegate?.pets, sender.tag < pets.count else { return }
        let pet = pets[sender.tag]
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
                appDelegate?.savePets()
                rebuildCatList()
            }
        }
    }

    @objc func removeCat(_ sender: NSButton) {
        guard let delegate = appDelegate, sender.tag < delegate.pets.count,
              delegate.pets.count > 1 else { return }
        if selectedPetIndex == sender.tag { selectedPetIndex = nil }
        else if let sel = selectedPetIndex, sel > sender.tag { selectedPetIndex = sel - 1 }
        let pet = delegate.pets.remove(at: sender.tag)
        pet.close()
        delegate.savePets()
        rebuildCatList()
    }

    @objc func addRandomCat() {
        appDelegate?.addRandomPet()
        rebuildCatList()
    }

    @objc func summonAll() {
        appDelegate?.summonAllPets()
    }

    @objc func removeAllCats() {
        guard let delegate = appDelegate, delegate.pets.count > 1 else { return }
        while delegate.pets.count > 1 {
            delegate.pets.removeLast().close()
        }
        selectedPetIndex = nil
        delegate.savePets()
        rebuildCatList()
    }

    // MARK: Settings Actions

    private func updateValueLabel(slider: NSSlider, format: String = "%.0f") {
        guard let view = slider.superview else { return }
        if let label = view.viewWithTag(1000 + slider.tag) as? NSTextField {
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
    let panelController = MainPanelController()

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard NSScreen.main != nil else {
            print("No screen found"); NSApp.terminate(nil); return
        }

        Config.restore()
        panelController.appDelegate = self
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

        // Pixel cat icon from Kittens pack (use variant detection)
        let iconVariant = findFirstVariant(folder: "Cat 1")
        let iconGIF = gifPathForCat(folder: "Cat 1", variant: iconVariant)
        if let thumb = extractThumbnail(gifPath: iconGIF, size: 18) {
            thumb.isTemplate = true
            statusItem.button?.image = thumb
        } else {
            statusItem.button?.title = "🐱"
        }

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

        let summonItem = NSMenuItem(title: "Summon All Cats", action: #selector(summonAllPets), keyEquivalent: "s")
        summonItem.target = self
        menu.addItem(summonItem)

        if pets.count > 1 {
            let rmItem = NSMenuItem(title: "Remove Last Cat", action: #selector(removeLastPet), keyEquivalent: "")
            rmItem.target = self
            menu.addItem(rmItem)

            let rmAllItem = NSMenuItem(title: "Remove All Cats", action: #selector(removeAllPets), keyEquivalent: "")
            rmAllItem.target = self
            menu.addItem(rmAllItem)
        }

        menu.addItem(.separator())

        for (i, pet) in pets.enumerated() {
            let title = "Cat #\(i + 1): \(pet.petName)"
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for c in 1...13 {
                let folder = "Cat \(c)"
                let ci = NSMenuItem(title: Config.catDisplayName(folder), action: #selector(statusChangeCat(_:)), keyEquivalent: "")
                ci.tag = i * 100 + c
                ci.target = self
                if pet.catFolder == folder { ci.state = .on }
                sub.addItem(ci)
            }
            item.submenu = sub
            menu.addItem(item)
        }

        menu.addItem(.separator())



        let panelItem = NSMenuItem(title: "Open Panel…", action: #selector(openPanel), keyEquivalent: ",")
        panelItem.target = self
        menu.addItem(panelItem)

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

    @objc func summonAllPets() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main!
        let bottomY = screen.visibleFrame.minY
        for (i, pet) in pets.enumerated() {
            let x = mouse.x - Config.windowSize / 2 + CGFloat(i) * (Config.windowSize + 10)
            pet.window.setFrameOrigin(NSPoint(x: x, y: bottomY))
            pet.view.gravityEnabled = true
            pet.brain.enter(.sitIdle)
        }
    }

    @objc func removeLastPet() {
        guard pets.count > 1 else { return }
        pets.removeLast().close()
        savePets()
    }

    @objc func removeAllPets() {
        guard pets.count > 1 else { return }
        while pets.count > 1 { pets.removeLast().close() }
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
            let folder = "Cat \(i)"
            let item = NSMenuItem(title: Config.catDisplayName(folder), action: #selector(ctxPickCat(_:)), keyEquivalent: "")
            item.tag = i; item.target = self
            if pet.catFolder == folder { item.state = .on }
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

        // Interactions
        let actSub = NSMenu()
        let actions: [(String, Int)] = [
            ("Sleep", 1), ("Meow", 2), ("Yawn", 3),
            ("Wash", 4), ("Scratch", 5), ("Zoomies", 6),
        ]
        for (title, tag) in actions {
            let item = NSMenuItem(title: title, action: #selector(ctxDoAction(_:)), keyEquivalent: "")
            item.tag = tag; item.target = self
            actSub.addItem(item)
        }
        let actItem = NSMenuItem(title: "Do…", action: nil, keyEquivalent: "")
        actItem.submenu = actSub
        menu.addItem(actItem)

        let renameItem = NSMenuItem(title: "Rename…", action: #selector(ctxRenamePet), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

        if pets.count > 1 {
            let rm = NSMenuItem(title: "Remove This Cat", action: #selector(ctxRemovePet), keyEquivalent: "")
            rm.target = self
            menu.addItem(rm)
        }

        menu.addItem(.separator())
        let panelItem = NSMenuItem(title: "Open Panel…", action: #selector(openPanel), keyEquivalent: ",")
        panelItem.target = self
        menu.addItem(panelItem)
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

    @objc func ctxDoAction(_ sender: NSMenuItem) {
        guard let pet = menuTargetPet else { return }
        switch sender.tag {
        case 1: pet.brain.enter(.sleeping)
        case 2: pet.brain.enter(.meowing)
        case 3: pet.brain.enter(.yawning)
        case 4: pet.brain.enter(.washing)
        case 5: pet.brain.enter(.scratching)
        case 6: pet.brain.enter(.zoomies)
        default: break
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

    @objc func openPanel() {
        panelController.show()
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
        return ""  // no subfolders, GIFs are directly in the cat folder
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
