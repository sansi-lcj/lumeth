import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("scripts/lumeth-icon-source.png")
let assetDirectory = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
guard let image = NSImage(contentsOf: source) else {
    fatalError("missing source icon: \(source.path)")
}

let variants: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
]

func render(size: Int) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    defer { NSGraphicsContext.restoreGraphicsState() }
    let scale = CGFloat(size) / 1024
    let context = graphics.cgContext
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let content = NSRect(
        x: 100 * scale,
        y: 100 * scale,
        width: 824 * scale,
        height: 824 * scale
    )
    let radius = 186 * scale
    let shape = NSBezierPath(roundedRect: content, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    context.setShadow(
        offset: CGSize(width: 0, height: -10 * scale),
        blur: 32 * scale,
        color: NSColor.black.withAlphaComponent(0.38).cgColor
    )
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    image.draw(
        in: content,
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1
    )
    let highlight = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.10),
        NSColor.white.withAlphaComponent(0.0)
    ])
    highlight?.draw(
        in: NSRect(x: content.minX, y: content.midY, width: content.width, height: content.height / 2),
        angle: -90
    )
    NSGraphicsContext.restoreGraphicsState()

    shape.lineWidth = max(1, 2.2 * scale)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    shape.stroke()

    return bitmap.representation(using: .png, properties: [:])
}

for (size, name) in variants {
    guard let data = render(size: size) else { continue }
    try data.write(to: assetDirectory.appendingPathComponent(name))
}

let iconset = root.appendingPathComponent("Resources/Lumeth.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (size, name) in variants {
    guard let data = render(size: size) else { continue }
    try data.write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns", iconset.path,
    "-o", root.appendingPathComponent("Resources/AppIcon.icns").path
]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("icons updated")
