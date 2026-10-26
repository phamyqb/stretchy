// Dùng: swift Resources/make-icon.swift  -> tạo Resources/AppIcon.icns
import AppKit

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Nền squircle (theo lưới icon macOS: chừa lề ~10%)
    let inset = s * 0.098
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = s * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.set()
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    let gradient = NSGradient(colors: [
        NSColor(red: 0.30, green: 0.88, blue: 0.70, alpha: 1),   // mint
        NSColor(red: 0.10, green: 0.66, blue: 0.72, alpha: 1),   // teal
        NSColor(red: 0.12, green: 0.52, blue: 0.88, alpha: 1),   // cyan-blue
    ])!
    gradient.draw(in: path, angle: -60)

    // Highlight nhẹ phía trên
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), .clear])!
        .draw(in: NSRect(x: 0, y: s * 0.5, width: s, height: s * 0.5), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Biểu tượng người đứng vươn vai
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.52, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "figure.arms.open", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let sz = sym.size
        let r = NSRect(x: (s - sz.width) / 2, y: (s - sz.height) / 2, width: sz.width, height: sz.height)
        NSGraphicsContext.saveGraphicsState()
        let sh = NSShadow()
        sh.shadowColor = NSColor.black.withAlphaComponent(0.2)
        sh.shadowBlurRadius = s * 0.02
        sh.shadowOffset = NSSize(width: 0, height: -s * 0.01)
        sh.set()
        sym.draw(in: r)
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("Resources")
let set = root.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: set)
try fm.createDirectory(at: set, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: set.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: set.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", root.appendingPathComponent("AppIcon.icns").path]
try p.run(); p.waitUntilExit()
try? fm.removeItem(at: set)
print(p.terminationStatus == 0 ? "✓ Resources/AppIcon.icns" : "✗ iconutil failed")
