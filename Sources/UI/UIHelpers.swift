import Cocoa
import ImageIO

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
