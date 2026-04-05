import Cocoa
import ImageIO

// Extract first frame from a GIF file
func firstFrame(_ path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          CGImageSourceGetCount(src) > 0 else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

// Find Kittens pack
let packPath: String = {
    for candidate in [
        "./Kittens pack",
        NSHomeDirectory() + "/Downloads/Kittens pack"
    ] {
        if FileManager.default.fileExists(atPath: candidate) { return candidate }
    }
    return "./Kittens pack"
}()

// Cats to show: (folder, variant, animation, label)
let cats: [(String, String, String)] = [
    ("Cat 4", "Cat 4", "walk_right.gif"),
    ("Cat 6", "Cat 6", "meow_sit.gif"),
    ("Cat 1", "Cat 1", "sleep1(r).gif"),
    ("Cat 9", "",       "wash_sit.gif"),
]

let scale = 6  // 16px × 6 = 96px per cat
let catSize = 16 * scale
let padding = 20
let totalW = cats.count * catSize + (cats.count - 1) * padding
let totalH = catSize

guard let ctx = CGContext(
    data: nil, width: totalW, height: totalH,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create context")
    exit(1)
}
ctx.interpolationQuality = .none

for (i, (folder, variant, anim)) in cats.enumerated() {
    let gifPath: String
    if variant.isEmpty {
        gifPath = "\(packPath)/\(folder)/\(anim)"
    } else {
        gifPath = "\(packPath)/\(folder)/\(variant)/\(anim)"
    }

    guard let frame = firstFrame(gifPath) else {
        print("Warning: Could not load \(gifPath)")
        continue
    }

    let x = i * (catSize + padding)
    ctx.draw(frame, in: CGRect(x: x, y: 0, width: catSize, height: catSize))
}

guard let image = ctx.makeImage() else {
    print("Failed to create image")
    exit(1)
}

let outURL = URL(fileURLWithPath: "assets/banner.png")
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil) else {
    print("Failed to create output")
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)

print("Created assets/banner.png (\(totalW)×\(totalH))")
