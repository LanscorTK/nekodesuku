import Cocoa
import ImageIO

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
