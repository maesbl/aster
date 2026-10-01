import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 512
    NSGraphicsContext.current?.imageInterpolation = .high
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 14, y: 14, width: 484, height: 484), xRadius: 108, yRadius: 108)
    NSGradient(starting: NSColor(white: 0.045, alpha: 1), ending: NSColor(white: 0.16, alpha: 1))!.draw(in: tile, angle: 80)
    NSColor(white: 1, alpha: 0.16).setStroke(); tile.lineWidth = 2; tile.stroke()
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.45); shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -14); shadow.set()
    let body = NSBezierPath(roundedRect: NSRect(x: 127, y: 116, width: 258, height: 280), xRadius: 99, yRadius: 99)
    NSGradient(starting: NSColor(white: 0.83, alpha: 1), ending: NSColor(white: 0.99, alpha: 1))!.draw(in: body, angle: 75)
    NSGraphicsContext.restoreGraphicsState()
    NSColor(white: 1, alpha: 0.85).setStroke(); body.lineWidth = 2; body.stroke()
    NSColor(white: 0.09, alpha: 1).setFill()
    for x in [208.0, 286.0] { NSBezierPath(roundedRect: NSRect(x: x, y: 250, width: 18, height: 36), xRadius: 9, yRadius: 9).fill() }
    let star = NSBezierPath(); star.move(to: NSPoint(x: 412, y: 431))
    for point in [NSPoint(x: 419, y: 412), NSPoint(x: 438, y: 405), NSPoint(x: 419, y: 398), NSPoint(x: 412, y: 379), NSPoint(x: 405, y: 398), NSPoint(x: 386, y: 405), NSPoint(x: 405, y: 412)] { star.line(to: point) }
    star.close(); NSColor(white: 0.93, alpha: 1).setFill(); star.fill()
    NSGraphicsContext.restoreGraphicsState()
    let png = bitmap.representation(using: .png, properties: [:])!
    let names: [String]
    switch size {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for name in names { try png.write(to: output.appendingPathComponent(name)) }
}
