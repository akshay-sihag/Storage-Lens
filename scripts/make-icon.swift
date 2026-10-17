import Cocoa
let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    let rect = NSRect(x: 32, y: 32, width: 960, height: 960)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
    NSGradient(starting: NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.28, alpha: 1), ending: NSColor(calibratedRed: 0.10, green: 0.52, blue: 0.52, alpha: 1))!.draw(in: shape, angle: 45)
    // Original Eridyn hard-drive illustration; no Apple/SF Symbols artwork is embedded.
    let drive = NSBezierPath(roundedRect: NSRect(x: 204, y: 278, width: 474, height: 522), xRadius: 54, yRadius: 54)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.23); shadow.shadowBlurRadius = 28; shadow.shadowOffset = NSSize(width: 0, height: -18); shadow.set()
    NSGradient(starting: NSColor(calibratedRed: 0.43, green: 0.91, blue: 0.78, alpha: 1), ending: NSColor(calibratedRed: 0.20, green: 0.65, blue: 0.59, alpha: 1))!.draw(in: drive, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.65).setStroke(); drive.lineWidth = 5; drive.stroke()
    let top = NSBezierPath(roundedRect: NSRect(x: 228, y: 372, width: 426, height: 402), xRadius: 32, yRadius: 32)
    NSGradient(starting: NSColor(calibratedRed: 0.53, green: 0.94, blue: 0.83, alpha: 1), ending: NSColor(calibratedRed: 0.33, green: 0.79, blue: 0.69, alpha: 1))!.draw(in: top, angle: -65)
    NSColor(calibratedRed: 0.1, green: 0.4, blue: 0.37, alpha: 0.45).setStroke(); top.lineWidth = 3; top.stroke()
    // Fine device detailing, kept sparse so the silhouette survives Dock sizes.
    NSColor(calibratedRed: 0.08, green: 0.33, blue: 0.32, alpha: 0.65).setFill()
    NSBezierPath(roundedRect: NSRect(x: 250, y: 314, width: 206, height: 12), xRadius: 6, yRadius: 6).fill()
    NSColor.white.withAlphaComponent(0.95).setFill()
    NSBezierPath(ovalIn: NSRect(x: 272, y: 338, width: 13, height: 13)).fill()
    for point in [NSPoint(x: 260, y: 738), NSPoint(x: 620, y: 738)] {
        NSColor(calibratedRed: 0.18, green: 0.52, blue: 0.47, alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: point.x, y: point.y, width: 13, height: 13)).fill()
    }
    let lensRect = NSRect(x: 398, y: 278, width: 344, height: 344)
    NSColor(calibratedRed: 0.08, green: 0.51, blue: 0.55, alpha: 0.18).setFill(); NSBezierPath(ovalIn: lensRect).fill()
    NSColor(calibratedWhite: 0.98, alpha: 1).setStroke()
    let handle = NSBezierPath(); handle.move(to: NSPoint(x: 692, y: 326)); handle.line(to: NSPoint(x: 821, y: 197)); handle.lineWidth = 70; handle.lineCapStyle = .round; handle.stroke()
    let ring = NSBezierPath(ovalIn: lensRect); ring.lineWidth = 49; ring.stroke()
    // A restrained glass highlight, not a stock magnifier glyph.
    let highlight = NSBezierPath(); highlight.appendArc(withCenter: NSPoint(x: 570, y: 450), radius: 126, startAngle: 70, endAngle: 145)
    NSColor.white.withAlphaComponent(0.42).setStroke(); highlight.lineWidth = 10; highlight.lineCapStyle = .round; highlight.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    if size <= 512 { try data.write(to: URL(fileURLWithPath: output + "/icon_\(size)x\(size).png")) }
    if size >= 32 { try data.write(to: URL(fileURLWithPath: output + "/icon_\(size/2)x\(size/2)@2x.png")) }
}
