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

// 3x3 grid of cats: (folder, variant, animation)
let cats: [(String, String, String)] = [
    ("Cat 4",  "Cat 4",   "walk_right.gif"),     // Orange walking
    ("Cat 6",  "Cat 6",   "meow_sit.gif"),       // Tuxedo meowing
    ("Cat 1",  "Cat 1",   "sleep1(r).gif"),      // Gray sleeping
    ("Cat 3",  "Cat 3",   "scratch(r).gif"),     // Black scratching
    ("Cat 9",  "",         "wash_sit.gif"),       // White washing
    ("Cat 2",  "Cat 2",   "on_hind_legs.gif"),   // Silver standing
    ("Cat 11", "",         "yawn_sit.gif"),       // Peach yawning
    ("Cat 7",  "Cat 7",   "walk_left.gif"),      // Chocolate walking
    ("Cat 10", "",         "hiss(r).gif"),        // Siamese hissing
]

let cols = 3
let scale = 6
let catSize = 16 * scale
let padding = 16
let totalW = cols * catSize + (cols - 1) * padding
let rows = (cats.count + cols - 1) / cols
let totalH = rows * catSize + (rows - 1) * padding

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

    let col = i % cols
    let row = i / cols
    let x = col * (catSize + padding)
    let y = totalH - (row + 1) * catSize - row * padding  // top-to-bottom
    ctx.draw(frame, in: CGRect(x: x, y: y, width: catSize, height: catSize))
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
