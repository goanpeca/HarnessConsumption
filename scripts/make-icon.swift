// Draws the app icon: a gauge ring (62% left, with the even-pace tick) around an "H", on a deep purple
// squircle. Run it to regenerate Resources/AppIcon.icns; the result is committed, so building the app
// does not need this.
//
//   swift scripts/make-icon.swift Resources/AppIcon.icns
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let accentGreen = NSColor(srgbRed: 0x62 / 255, green: 0xBA / 255, blue: 0x46 / 255, alpha: 1)

/// A superellipse, the shape macOS app icons use (rounder than a rounded rectangle).
func squircle(in rect: CGRect) -> NSBezierPath {
    let path = NSBezierPath()
    let exponent = 5.0
    let steps = 360
    for step in 0...steps {
        let angle = Double(step) / Double(steps) * 2 * .pi
        let cosine = cos(angle)
        let sine = sin(angle)
        let x = rect.midX + rect.width / 2 * CGFloat(copysign(pow(abs(cosine), 2 / exponent), cosine))
        let y = rect.midY + rect.height / 2 * CGFloat(copysign(pow(abs(sine), 2 / exponent), sine))
        if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.line(to: CGPoint(x: x, y: y)) }
    }
    path.close()
    return path
}

func arc(center: CGPoint, radius: CGFloat, from start: CGFloat, to end: CGFloat, width: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
    path.lineWidth = width
    path.lineCapStyle = .round
    return path
}

func render(pixels: Int) -> Data? {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    // Draw on a 1024-point canvas, scaled to the requested size.
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / 1024)
    transform.concat()

    // The body is 824 points with a 100-point margin, as in Apple's icon template.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = squircle(in: body)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = CGSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 28
    shadow.set()
    NSColor(srgbRed: 0.10, green: 0.08, blue: 0.20, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(
        colors: [
            NSColor(srgbRed: 0.33, green: 0.24, blue: 0.62, alpha: 1),
            NSColor(srgbRed: 0.13, green: 0.10, blue: 0.27, alpha: 1),
        ])?.draw(in: shape, angle: -90)

    shape.addClip()
    NSColor.white.withAlphaComponent(0.10).setStroke()
    shape.lineWidth = 4
    shape.stroke()

    // The gauge: 270 degrees, open at the bottom, filled clockwise from the lower left.
    let center = CGPoint(x: 512, y: 520)
    let radius: CGFloat = 250
    let start: CGFloat = 225
    let total: CGFloat = 270
    NSColor.white.withAlphaComponent(0.16).setStroke()
    arc(center: center, radius: radius, from: start, to: start - total, width: 64).stroke()
    accentGreen.setStroke()
    arc(center: center, radius: radius, from: start, to: start - total * 0.62, width: 64).stroke()

    // The even-pace tick, as in the app's bars.
    let paceAngle = (start - total * 0.78) * .pi / 180
    let tick = NSBezierPath()
    tick.move(to: CGPoint(x: center.x + (radius - 52) * cos(paceAngle), y: center.y + (radius - 52) * sin(paceAngle)))
    tick.line(to: CGPoint(x: center.x + (radius + 52) * cos(paceAngle), y: center.y + (radius + 52) * sin(paceAngle)))
    tick.lineWidth = 16
    tick.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.92).setStroke()
    tick.stroke()

    // The "H" in the middle: two stems and a crossbar.
    NSColor(white: 0.97, alpha: 1).setFill()
    for rect in [
        CGRect(x: 416, y: 410, width: 58, height: 220), CGRect(x: 550, y: 410, width: 58, height: 220),
        CGRect(x: 440, y: 492, width: 144, height: 52),
    ] {
        NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14).fill()
    }

    return bitmap.representation(using: .png, properties: [:])
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift scripts/make-icon.swift Resources/AppIcon.icns\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = output.deletingPathExtension().appendingPathExtension("iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// The iconset names pair each point size with its 1x and 2x renderings.
let names: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"), (64, "icon_32x32@2x"), (128, "icon_128x128"),
    (256, "icon_128x128@2x"), (256, "icon_256x256"), (512, "icon_256x256@2x"), (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]
for (pixels, name) in names {
    guard let data = render(pixels: pixels) else { exit(1) }
    try data.write(to: iconset.appendingPathComponent("\(name).png"))
}

let tool = Process()
tool.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
tool.arguments = ["-c", "icns", "-o", output.path, iconset.path]
try tool.run()
tool.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(tool.terminationStatus)
