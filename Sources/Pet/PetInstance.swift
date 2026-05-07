import Cocoa

// ============================================================================
// MARK: - Pet Instance
// ============================================================================

struct PetStats {
    var clicks: Int = 0
    var pettings: Int = 0
    var zoomies: Int = 0
    var climbCount: Int = 0
    var totalDistance: CGFloat = 0
    var sleepTime: TimeInterval = 0
    var createdAt: TimeInterval = ProcessInfo.processInfo.systemUptime

    func toDict() -> [String: Any] {
        ["clicks": clicks, "pettings": pettings, "zoomies": zoomies,
         "climbCount": climbCount, "totalDistance": Double(totalDistance),
         "sleepTime": sleepTime, "createdAt": createdAt]
    }

    static func from(_ d: [String: Any]) -> PetStats {
        var s = PetStats()
        s.clicks = d["clicks"] as? Int ?? 0
        s.pettings = d["pettings"] as? Int ?? 0
        s.zoomies = d["zoomies"] as? Int ?? 0
        s.climbCount = d["climbCount"] as? Int ?? 0
        s.totalDistance = CGFloat(d["totalDistance"] as? Double ?? 0)
        s.sleepTime = d["sleepTime"] as? TimeInterval ?? 0
        s.createdAt = d["createdAt"] as? TimeInterval ?? ProcessInfo.processInfo.systemUptime
        return s
    }
}

class PetInstance {
    let window: NSWindow
    let view: PetView
    let brain: PetBrain
    var catFolder: String
    var catVariant: String
    var petName: String
    var lastTick: TimeInterval
    var nameWindow: NSWindow?
    var stats = PetStats()
    var prevState: PetState = .sitIdle
    var ctx: CatContext = .fresh()
    private var ctxAccum: TimeInterval = 0

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

        ctxAccum += dt
        if ctxAccum >= 1.0 {
            updateContext(&ctx,
                          perception: PerceptionLayer.shared.current(),
                          currentState: brain.state,
                          dt: ctxAccum)
            ctxAccum = 0
        }
        brain.ownerCtx = ctx

        // Detect long press → petting (rewards the bandit when the user holds within 5s)
        if view.isDragging && !view.wasDragged {
            if case .petting = brain.state { }
            else if (now - view.mouseDownTime) > 1.0 {
                if (now - brain.actionStartTime) <= 5.0 {
                    brain.recordReward(+1.5)
                }
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
            let bottomY: CGFloat
            if Config.windowAwareness {
                bottomY = (NSApp.delegate as? AppDelegate)?
                    .windowTracker.landingSurface(petX: origin.x, petY: origin.y,
                                                  petW: Config.windowSize, screenMinY: screenBounds.minY)
                    ?? screenBounds.minY
            } else {
                bottomY = screenBounds.minY
            }
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
            stats.totalDistance += abs(move.dx) + abs(move.dy)
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

        // Track stats
        if case .sleeping = brain.state { stats.sleepTime += dt }
        if brain.state != prevState {
            if case .zoomies = brain.state { stats.zoomies += 1 }
            if case .climbEdge = brain.state { stats.climbCount += 1 }
            prevState = brain.state
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
