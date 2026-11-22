import AppKit

// Usage: Icon <output.iconset> [dmg-background.png]
// All artwork is drawn in AppKit; no third-party assets or network access.
let ice = NSColor(calibratedRed: 0.83, green: 0.90, blue: 0.95, alpha: 1)
let steel = NSColor(calibratedRed: 0.16, green: 0.31, blue: 0.45, alpha: 1)
let blue = NSColor(calibratedRed: 0.17, green: 0.39, blue: 0.57, alpha: 1)
let gold = NSColor(calibratedRed: 0.96, green: 0.70, blue: 0.31, alpha: 1)

func png(width: Int, height: Int, logicalWidth: Double, logicalHeight: Double,
         draw: () -> Void) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    let transform = NSAffineTransform()
    transform.scaleX(by: Double(width) / logicalWidth, yBy: Double(height) / logicalHeight)
    transform.concat()
    NSGraphicsContext.current?.imageInterpolation = .high
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

func drawIcon() {
    let tile = NSBezierPath(roundedRect: NSRect(x: 45, y: 45, width: 934, height: 934),
                            xRadius: 210, yRadius: 210)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = steel.withAlphaComponent(0.27)
    shadow.shadowBlurRadius = 27
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    ice.setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [NSColor(calibratedRed: 0.71, green: 0.82, blue: 0.89, alpha: 1),
                        ice, NSColor(calibratedWhite: 0.995, alpha: 1)])!.draw(in: tile, angle: 90)
    NSColor.white.withAlphaComponent(0.85).setStroke()
    tile.lineWidth = 5; tile.stroke()
    let inner = NSBezierPath(roundedRect: NSRect(x: 68, y: 68, width: 888, height: 888),
                             xRadius: 190, yRadius: 190)
    steel.withAlphaComponent(0.06).setStroke(); inner.lineWidth = 2; inner.stroke()

    let disc = NSBezierPath(ovalIn: NSRect(x: 207, y: 207, width: 610, height: 610))
    NSGraphicsContext.saveGraphicsState()
    let discShadow = NSShadow()
    discShadow.shadowColor = steel.withAlphaComponent(0.25)
    discShadow.shadowBlurRadius = 22
    discShadow.shadowOffset = NSSize(width: 0, height: -13)
    discShadow.set(); steel.setFill(); disc.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [steel, blue, NSColor(calibratedRed: 0.33, green: 0.56, blue: 0.73, alpha: 1)])!
        .draw(in: disc, angle: 90)
    NSColor.white.withAlphaComponent(0.5).setStroke()
    disc.lineWidth = 3; disc.stroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: 225, y: 225, width: 574, height: 574))
    NSColor.white.withAlphaComponent(0.10).setStroke(); ring.lineWidth = 2; ring.stroke()

    let heights: [Double] = [115, 225, 355, 225, 115]
    for (index, height) in heights.enumerated() {
        let x = 388.0 + Double(index) * 62
        let line = NSBezierPath()
        line.move(to: NSPoint(x: x, y: 512 - height / 2))
        line.line(to: NSPoint(x: x, y: 512 + height / 2))
        line.lineWidth = 31
        line.lineCapStyle = .round
        (index == 2 ? gold : NSColor(calibratedRed: 0.91, green: 0.97, blue: 1, alpha: 1)).setStroke()
        line.stroke()
    }
    // One small light catches the edge, like a familiar physical studio control.
    let light = NSBezierPath(ovalIn: NSRect(x: 746, y: 759, width: 28, height: 28))
    gold.setFill(); light.fill()
}

func text(_ value: String, in rect: NSRect, size: CGFloat,
          weight: NSFont.Weight = .regular, color: NSColor = steel,
          alignment: NSTextAlignment = .center) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    (value as NSString).draw(in: rect, withAttributes: attributes)
}

func drawDMG() {
    NSGradient(colors: [NSColor(calibratedRed: 0.81, green: 0.88, blue: 0.94, alpha: 1),
                        NSColor(calibratedRed: 0.98, green: 0.99, blue: 1, alpha: 1)])!
        .draw(in: NSBezierPath(rect: NSRect(x: 0, y: 0, width: 720, height: 460)), angle: 90)
    text("SOS DIGITAL . PRO", in: NSRect(x: 40, y: 408, width: 640, height: 20),
         size: 11, weight: .semibold, color: blue)
    text("Generator Muzyki", in: NSRect(x: 40, y: 356, width: 640, height: 46),
         size: 33, weight: .semibold)
    text("Cała kolekcja muzyki. Jeden start.", in: NSRect(x: 40, y: 328, width: 640, height: 24),
         size: 14, color: steel.withAlphaComponent(0.75))
    for x: CGFloat in [90, 430] {
        let platform = NSBezierPath(roundedRect: NSRect(x: x, y: 154, width: 200, height: 144),
                                     xRadius: 22, yRadius: 22)
        NSColor.white.withAlphaComponent(0.42).setFill(); platform.fill()
        NSColor.white.withAlphaComponent(0.74).setStroke(); platform.lineWidth = 1; platform.stroke()
    }
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 330, y: 226)); arrow.line(to: NSPoint(x: 390, y: 226))
    arrow.move(to: NSPoint(x: 377, y: 240)); arrow.line(to: NSPoint(x: 391, y: 226))
    arrow.line(to: NSPoint(x: 377, y: 212))
    arrow.lineWidth = 3; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
    blue.withAlphaComponent(0.7).setStroke(); arrow.stroke()
    text("Przeciągnij do Aplikacji", in: NSRect(x: 40, y: 91, width: 640, height: 28),
         size: 19, weight: .medium)
    text("Silnik i utwory pozostają w folderze ACE na dysku.",
         in: NSRect(x: 40, y: 64, width: 640, height: 22), size: 12, color: steel.withAlphaComponent(0.75))
    // Restrained waveform along the bottom provides a shared visual signature.
    let heights: [CGFloat] = [3, 8, 12, 7, 20, 27, 14, 8, 17, 11, 6, 3]
    for (i, height) in heights.enumerated() {
        let bar = NSBezierPath()
        let x = 316 + CGFloat(i) * 8
        bar.move(to: NSPoint(x: x, y: 27 - height / 2))
        bar.line(to: NSPoint(x: x, y: 27 + height / 2))
        bar.lineWidth = 2; bar.lineCapStyle = .round
        (i == 5 ? gold : blue.withAlphaComponent(0.22)).setStroke(); bar.stroke()
    }
}

let arguments = CommandLine.arguments
if arguments.count < 2 {
    fputs("Usage: Icon <output.iconset> [dmg-background.png]\n", stderr)
    exit(2)
}
let iconset = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 1 ? "" : "@2x"
        let filename = "icon_\(size)x\(size)\(suffix).png"
        try png(width: size * scale, height: size * scale, logicalWidth: 1024, logicalHeight: 1024,
                draw: drawIcon).write(to: iconset.appendingPathComponent(filename))
    }
}
if arguments.count >= 3 {
    let output = URL(fileURLWithPath: arguments[2])
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png(width: 720, height: 460, logicalWidth: 720, logicalHeight: 460, draw: drawDMG).write(to: output)
}
print("Icon artwork written to \(iconset.path)")
