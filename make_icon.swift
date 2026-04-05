#!/usr/bin/env swift
// Generates AppIcon.icns from a Kittens pack sprite GIF.
// Usage: swift make_icon.swift ["/path/to/Kittens pack"]

import Foundation
import ImageIO
import CoreGraphics

// Resolve Kittens pack path
func findPack() -> String {
    if CommandLine.arguments.count > 1 { return CommandLine.arguments[1] }
    let fm = FileManager.default
    for candidate in [
        "./Kittens pack",
        NSHomeDirectory() + "/Downloads/Kittens pack",
        NSHomeDirectory() + "/Desktop/Kittens pack"
    ] {
        if fm.fileExists(atPath: candidate) { return candidate }
    }
    print("Error: Kittens pack not found. Pass the path as argument.")
    exit(1)
}

let pack = findPack()
let gifPath = pack + "/Cat 1/Cat 1/meow_sit.gif"

guard FileManager.default.fileExists(atPath: gifPath) else {
    print("Error: \(gifPath) not found")
    exit(1)
}

// Extract first frame from GIF
let url = URL(fileURLWithPath: gifPath)
guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
      CGImageSourceGetCount(src) > 0,
      let frame = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    print("Error: Failed to read GIF frame")
    exit(1)
}

print("Source sprite: \(frame.width)x\(frame.height)px")

// Scale with nearest-neighbor (preserves pixel art)
func scalePixelArt(_ image: CGImage, to size: Int) -> CGImage? {
    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .none
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()
}

// Icon sizes required for .iconset
let iconSizes: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

// Create .iconset directory
let iconsetDir = "AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetDir)
try fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

for entry in iconSizes {
    guard let scaled = scalePixelArt(frame, to: entry.size) else {
        print("Error: Failed to scale to \(entry.size)x\(entry.size)")
        exit(1)
    }
    let outURL = URL(fileURLWithPath: "\(iconsetDir)/\(entry.name)")
    guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil) else {
        print("Error: Failed to create PNG destination")
        exit(1)
    }
    CGImageDestinationAddImage(dest, scaled, nil)
    CGImageDestinationFinalize(dest)
    print("  \(entry.name) (\(entry.size)x\(entry.size))")
}

// Convert to .icns
print("Converting to AppIcon.icns...")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["--convert", "icns", iconsetDir, "--output", "AppIcon.icns"]
try proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    try? fm.removeItem(atPath: iconsetDir)
    print("Done! AppIcon.icns created.")
} else {
    print("Error: iconutil failed with status \(proc.terminationStatus)")
    exit(1)
}
