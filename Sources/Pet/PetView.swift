import Cocoa

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
        (NSApp.delegate as? AppDelegate)?.lastInteractionTime = mouseDownTime
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
                instance?.stats.pettings += 1
            } else if let brain = instance?.brain {
                let now = ProcessInfo.processInfo.systemUptime
                if (now - brain.actionStartTime) <= 3.0 {
                    brain.recordReward(+1.0)
                }
                brain.triggerClickReact()
                instance?.stats.clicks += 1
            }
        }
        isDragging = false
    }

    override func rightMouseDown(with e: NSEvent) {
        guard let inst = instance else { return }
        inst.brain.recordReward(-0.3)
        (NSApp.delegate as? AppDelegate)?.showPetMenu(for: inst, event: e)
    }
}
