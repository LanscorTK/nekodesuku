import Cocoa

// ============================================================================
// MARK: - Window Tracker
// ============================================================================

class WindowTracker {
    var windowRects: [NSRect] = []
    private var lastUpdate: TimeInterval = 0
    private let myPID = ProcessInfo.processInfo.processIdentifier

    func update() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastUpdate > 0.5 else { return }
        lastUpdate = now

        guard let infoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return }

        let screenH = NSScreen.main?.frame.height ?? 0

        windowRects = infoList.compactMap { info -> NSRect? in
            guard let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let alpha = info[kCGWindowAlpha as String] as? Double, alpha > 0.5,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? Int,
                  pid != Int(myPID)
            else { return nil }

            guard let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let w = bounds["Width"] as? CGFloat,
                  let h = bounds["Height"] as? CGFloat,
                  w > 50, h > 30  // skip tiny windows (tooltips, etc.)
            else { return nil }

            // Convert from top-left origin (CGWindow) to bottom-left origin (Cocoa)
            return NSRect(x: x, y: screenH - y - h, width: w, height: h)
        }
    }

    func landingSurface(petX: CGFloat, petY: CGFloat, petW: CGFloat, screenMinY: CGFloat) -> CGFloat {
        var bestY = screenMinY
        for win in windowRects {
            let winTop = win.maxY
            if winTop <= petY + 2 && winTop > bestY &&
               petX + petW > win.minX && petX < win.maxX {
                bestY = winTop
            }
        }
        return bestY
    }
}
