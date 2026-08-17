import AppKit
import Foundation

enum IconError: Error {
    case missingOutputDirectory
    case bitmapCreationFailed
    case pngCreationFailed
}

guard CommandLine.arguments.count == 2 else {
    throw IconError.missingOutputDirectory
}

let outputDirectory = URL(
    fileURLWithPath: CommandLine.arguments[1],
    isDirectory: true
)
try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

let definitions: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconError.bitmapCreationFailed
    }

    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let size = CGFloat(pixels)
    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = size * 0.055
    let backgroundRect = canvas.insetBy(dx: inset, dy: inset)
    let background = NSBezierPath(
        roundedRect: backgroundRect,
        xRadius: size * 0.22,
        yRadius: size * 0.22
    )
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.55, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.26, green: 0.24, blue: 0.82, alpha: 1)
    ])
    gradient?.draw(in: background, angle: -45)

    NSGraphicsContext.saveGraphicsState()
    background.addClip()
    let glowRect = NSRect(
        x: -size * 0.1,
        y: size * 0.46,
        width: size * 0.82,
        height: size * 0.72
    )
    NSColor.white.withAlphaComponent(0.14).setFill()
    NSBezierPath(ovalIn: glowRect).fill()
    NSGraphicsContext.restoreGraphicsState()

    let branch = NSBezierPath()
    branch.lineWidth = max(1.2, size * 0.075)
    branch.lineCapStyle = .round
    branch.lineJoinStyle = .round
    branch.move(to: NSPoint(x: size * 0.34, y: size * 0.72))
    branch.line(to: NSPoint(x: size * 0.34, y: size * 0.30))
    branch.move(to: NSPoint(x: size * 0.34, y: size * 0.53))
    branch.curve(
        to: NSPoint(x: size * 0.68, y: size * 0.69),
        controlPoint1: NSPoint(x: size * 0.50, y: size * 0.53),
        controlPoint2: NSPoint(x: size * 0.49, y: size * 0.69)
    )
    NSColor.white.withAlphaComponent(0.94).setStroke()
    branch.stroke()

    let nodes = [
        NSPoint(x: size * 0.34, y: size * 0.74),
        NSPoint(x: size * 0.34, y: size * 0.28),
        NSPoint(x: size * 0.69, y: size * 0.70)
    ]
    let nodeRadius = size * 0.105
    for point in nodes {
        let shadow = NSBezierPath(
            ovalIn: NSRect(
                x: point.x - nodeRadius * 1.18,
                y: point.y - nodeRadius * 1.18,
                width: nodeRadius * 2.36,
                height: nodeRadius * 2.36
            )
        )
        NSColor.black.withAlphaComponent(0.13).setFill()
        shadow.fill()

        let node = NSBezierPath(
            ovalIn: NSRect(
                x: point.x - nodeRadius,
                y: point.y - nodeRadius,
                width: nodeRadius * 2,
                height: nodeRadius * 2
            )
        )
        NSColor.white.setFill()
        node.fill()

        let center = NSBezierPath(
            ovalIn: NSRect(
                x: point.x - nodeRadius * 0.34,
                y: point.y - nodeRadius * 0.34,
                width: nodeRadius * 0.68,
                height: nodeRadius * 0.68
            )
        )
        NSColor(calibratedRed: 0.18, green: 0.39, blue: 0.91, alpha: 1).setFill()
        center.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconError.pngCreationFailed
    }
    return data
}

for definition in definitions {
    let data = try drawIcon(pixels: definition.pixels)
    try data.write(to: outputDirectory.appendingPathComponent(definition.name))
}
