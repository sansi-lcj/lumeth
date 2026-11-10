import AppKit
import Foundation

let output = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "Resources")
let iconset = output.appendingPathComponent("Pulse.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(size: Int) -> Data? {
    let dimension = CGFloat(size)
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
    let context = graphics.cgContext

    let outer = NSRect(x: 0, y: 0, width: dimension, height: dimension)
    let radius = dimension * 0.225
    let clip = NSBezierPath(roundedRect: outer, xRadius: radius, yRadius: radius)
    clip.addClip()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.055, green: 0.05, blue: 0.10, alpha: 1),
        NSColor(calibratedRed: 0.16, green: 0.06, blue: 0.22, alpha: 1)
    ])
    gradient?.draw(in: outer, angle: -90)

    context.setShadow(
        offset: .zero,
        blur: dimension * 0.055,
        color: NSColor(calibratedRed: 0.30, green: 0.95, blue: 0.76, alpha: 0.45).cgColor
    )
    let points = [
        NSPoint(x: dimension * 0.16, y: dimension * 0.50),
        NSPoint(x: dimension * 0.31, y: dimension * 0.50),
        NSPoint(x: dimension * 0.40, y: dimension * 0.68),
        NSPoint(x: dimension * 0.52, y: dimension * 0.28),
        NSPoint(x: dimension * 0.62, y: dimension * 0.56),
        NSPoint(x: dimension * 0.73, y: dimension * 0.56),
        NSPoint(x: dimension * 0.84, y: dimension * 0.50)
    ]
    let colors = [
        NSColor(calibratedRed: 1.00, green: 0.37, blue: 0.46, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.57, blue: 0.25, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.28, alpha: 1),
        NSColor(calibratedRed: 0.28, green: 0.90, blue: 0.66, alpha: 1),
        NSColor(calibratedRed: 0.24, green: 0.84, blue: 0.94, alpha: 1),
        NSColor(calibratedRed: 0.60, green: 0.45, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.96, green: 0.38, blue: 0.86, alpha: 1)
    ]
    for index in 0..<(points.count - 1) {
        let segment = NSBezierPath()
        segment.lineWidth = max(2, dimension * 0.055)
        segment.lineCapStyle = .round
        segment.lineJoinStyle = .round
        segment.move(to: points[index])
        segment.line(to: points[index + 1])
        colors[index].setStroke()
        segment.stroke()
    }

    return bitmap.representation(using: .png, properties: [:])
}

let variants: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
]

for (size, name) in variants {
    guard let data = render(size: size) else { continue }
    try data.write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.appendingPathComponent("AppIcon.icns").path]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("icon: \(output.appendingPathComponent("AppIcon.icns").path)")
