// Storage Lens — By Eridyn. Original installer artwork.
import Cocoa
let image = NSImage(size: NSSize(width: 720, height: 450))
for factor in [1, 2] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 720 * factor, pixelsHigh: 450 * factor, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform(); transform.scale(by: CGFloat(factor)); transform.concat()
    NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.97, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: 720, height: 450).fill()
    func centered(_ text: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
        let w = (text as NSString).size(withAttributes: attrs).width
        (text as NSString).draw(at: NSPoint(x: (720-w)/2, y: y), withAttributes: attrs)
    }
    let ink = NSColor(calibratedRed: 0.10, green: 0.25, blue: 0.28, alpha: 1)
    centered("Storage Lens", y: 365, size: 30, weight: .semibold, color: ink)
    centered("Drag Storage Lens to Applications", y: 334, size: 15, weight: .regular, color: ink.withAlphaComponent(0.74))
    let arrow = NSBezierPath(); arrow.move(to: NSPoint(x: 322, y: 230)); arrow.line(to: NSPoint(x: 398, y: 230)); arrow.move(to: NSPoint(x: 382, y: 246)); arrow.line(to: NSPoint(x: 398, y: 230)); arrow.line(to: NSPoint(x: 382, y: 214)); arrow.lineWidth = 4; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
    NSColor(calibratedRed: 0.17, green: 0.58, blue: 0.55, alpha: 1).setStroke(); arrow.stroke()
    NSGraphicsContext.restoreGraphicsState(); rep.size = NSSize(width: 720, height: 450); image.addRepresentation(rep)
}
try image.tiffRepresentation!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
