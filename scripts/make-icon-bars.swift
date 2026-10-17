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
    let ring = NSBezierPath(ovalIn: NSRect(x: 210, y: 290, width: 510, height: 510)); ring.lineWidth = 62; NSColor.white.withAlphaComponent(0.94).setStroke(); ring.stroke()
    let handle = NSBezierPath(); handle.move(to: NSPoint(x: 666, y: 348)); handle.line(to: NSPoint(x: 818, y: 196)); handle.lineWidth = 78; handle.lineCapStyle = .round; handle.stroke()
    for (i, height) in [110.0, 210.0, 290.0].enumerated() {
        NSColor(calibratedRed: 0.43, green: 0.91, blue: 0.78, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 326 + Double(i)*102, y: 408, width: 64, height: height), xRadius: 19, yRadius: 19).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    if size <= 512 { try data.write(to: URL(fileURLWithPath: output + "/icon_\(size)x\(size).png")) }
    if size >= 32 { try data.write(to: URL(fileURLWithPath: output + "/icon_\(size/2)x\(size/2)@2x.png")) }
}
