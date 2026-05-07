import Cocoa

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

    // Policy + bandit (commit 2/3): chooseAction reads ownerCtx; recordReward attributes
    // to lastChosenAction (set by pickNext, not by every enter() — chained transitions
    // like sleeping → yawning still credit the bandit's original sleeping pick).
    var ownerCtx: CatContext = .fresh()
    var bandit: Bandit = Bandit()
    var lastChosenAction: PetState = .sitIdle
    var actionStartTime: TimeInterval = 0
    private var idleSwatFiredThisSession: Bool = false

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
            if ownerCtx.mood == .agitated { stateDuration *= 2 }
            setAnim("walk_r")
        case .walkLeft:
            facingRight = false
            stateDuration = .random(in: 3...7)
            if ownerCtx.mood == .agitated { stateDuration *= 2 }
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
        let p = PerceptionLayer.shared.current()
        let now = ProcessInfo.processInfo.systemUptime

        // Re-arm idle-swat once the user comes back to the keyboard.
        if p.idleTimeSeconds < 30 { idleSwatFiredThisSession = false }

        // Idle-swat: time-only trigger, fires exactly once per idle session.
        if Config.idleSwatMinutes > 0
            && p.idleTimeSeconds > Config.idleSwatMinutes * 60
            && !idleSwatFiredThisSession {
            idleSwatFiredThisSession = true
            lastChosenAction = .followMouse
            actionStartTime = now
            enter(.followMouse)
            return
        }

        let action = BehaviorPolicy.chooseAction(ctx: ownerCtx, perception: p, bandit: bandit)
        lastChosenAction = action
        actionStartTime = now
        enter(action)
    }

    /// Attribute a reward to whichever action the policy most recently chose. Reactive
    /// states (clickReact, petting) and environment-triggered states are not bandit
    /// targets, so they're skipped — the bandit only learns from policy-selected actions.
    func recordReward(_ r: Double) {
        guard BehaviorPolicy.banditEligible.contains(lastChosenAction) else { return }
        bandit.record(action: lastChosenAction, reward: r)
    }
}
