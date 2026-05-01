#!/usr/bin/env swift
import AppKit
import Foundation

private let rootURL = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
private let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
private let previewURL = resourcesURL.appendingPathComponent("AppIcon-preview.png")
private let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")

private let fileManager = FileManager.default
try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
if fileManager.fileExists(atPath: iconsetURL.path) {
    try fileManager.removeItem(at: iconsetURL)
}
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

private let iconFiles: [(points: Int, scale: Int, name: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png")
]

for file in iconFiles {
    let pixels = file.points * file.scale
    let data = try renderIcon(pixels: pixels)
    try data.write(to: iconsetURL.appendingPathComponent(file.name), options: .atomic)
}

let previewData = try renderIcon(pixels: 1024)
try previewData.write(to: previewURL, options: .atomic)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}

print("Generated \(icnsURL.path)")
print("Generated \(previewURL.path)")

private func renderIcon(pixels: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else {
        throw IconError.bitmapCreationFailed
    }

    rep.size = NSSize(width: pixels, height: pixels)
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw IconError.graphicsContextFailed
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(size: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw IconError.pngEncodingFailed
    }
    return data
}

private func drawIcon(size: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let margin = size * 0.055
    let baseRect = rect.insetBy(dx: margin, dy: margin)
    let corner = size * 0.205
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: corner, yRadius: corner)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = size * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.016)
    shadow.set()
    NSGradient(colors: [
        NSColor(hex: 0x000099),
        NSColor(hex: 0x1515B8),
        NSColor(hex: 0x4D4DFF)
    ])?.draw(in: basePath, angle: -38)
    NSGraphicsContext.restoreGraphicsState()

    drawCornerGlow(size: size, clip: basePath)
    drawShortcutConnector(size: size)
    drawSkillCard(size: size, rect: NSRect(x: size * 0.18, y: size * 0.62, width: size * 0.275, height: size * 0.165), kind: .input)
    drawSkillCard(size: size, rect: NSRect(x: size * 0.545, y: size * 0.42, width: size * 0.275, height: size * 0.165), kind: .skill)
    drawSkillCard(size: size, rect: NSRect(x: size * 0.18, y: size * 0.22, width: size * 0.275, height: size * 0.165), kind: .check)

    let rim = NSBezierPath(roundedRect: baseRect.insetBy(dx: size * 0.006, dy: size * 0.006), xRadius: corner * 0.95, yRadius: corner * 0.95)
    NSColor.white.withAlphaComponent(0.20).setStroke()
    rim.lineWidth = max(1, size * 0.008)
    rim.stroke()
}

private func drawCornerGlow(size: CGFloat, clip: NSBezierPath) {
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()

    let orangePath = NSBezierPath(ovalIn: NSRect(x: size * 0.50, y: size * 0.71, width: size * 0.50, height: size * 0.42))
    NSColor(hex: 0xFE8F11).withAlphaComponent(0.38).setFill()
    orangePath.fill()

    let warmPath = NSBezierPath(ovalIn: NSRect(x: size * -0.10, y: size * -0.12, width: size * 0.52, height: size * 0.45))
    NSColor(hex: 0x1195EB).withAlphaComponent(0.28).setFill()
    warmPath.fill()

    NSGraphicsContext.restoreGraphicsState()
}

private func drawShortcutConnector(size: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: size * 0.43, y: size * 0.70))
    path.curve(
        to: NSPoint(x: size * 0.58, y: size * 0.505),
        controlPoint1: NSPoint(x: size * 0.52, y: size * 0.70),
        controlPoint2: NSPoint(x: size * 0.49, y: size * 0.505)
    )
    path.curve(
        to: NSPoint(x: size * 0.43, y: size * 0.305),
        controlPoint1: NSPoint(x: size * 0.49, y: size * 0.505),
        controlPoint2: NSPoint(x: size * 0.52, y: size * 0.305)
    )
    path.lineWidth = max(3, size * 0.052)
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    NSColor(hex: 0xFE8F11).setStroke()
    path.stroke()

    let highlight = path.copy() as! NSBezierPath
    highlight.lineWidth = max(1, size * 0.017)
    NSColor.white.withAlphaComponent(0.55).setStroke()
    highlight.stroke()
}

private enum CardKind {
    case input
    case skill
    case check
}

private func drawSkillCard(size: CGFloat, rect: NSRect, kind: CardKind) {
    let radius = size * 0.034
    let card = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    shadow.shadowBlurRadius = size * 0.020
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.010)
    shadow.set()
    NSColor(hex: 0xF9F7F5).setFill()
    card.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.78).setStroke()
    card.lineWidth = max(1, size * 0.006)
    card.stroke()

    switch kind {
    case .input:
        drawInputGlyph(in: rect, size: size)
    case .skill:
        drawSkillGlyph(in: rect, size: size)
    case .check:
        drawCheckGlyph(in: rect, size: size)
    }
}

private func drawInputGlyph(in rect: NSRect, size: CGFloat) {
    let blue = NSColor(hex: 0x000099)
    let documentRect = NSRect(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.20, width: rect.width * 0.24, height: rect.height * 0.56)
    let doc = NSBezierPath(roundedRect: documentRect, xRadius: size * 0.010, yRadius: size * 0.010)
    blue.withAlphaComponent(0.12).setFill()
    doc.fill()
    blue.setStroke()
    doc.lineWidth = max(1, size * 0.006)
    doc.stroke()

    drawLine(from: NSPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.66), to: NSPoint(x: rect.minX + rect.width * 0.80, y: rect.minY + rect.height * 0.66), color: blue, width: size * 0.014)
    drawLine(from: NSPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.50), to: NSPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.50), color: blue.withAlphaComponent(0.70), width: size * 0.012)
    drawLine(from: NSPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.36), to: NSPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.36), color: blue.withAlphaComponent(0.55), width: size * 0.010)
}

private func drawSkillGlyph(in rect: NSRect, size: CGFloat) {
    let blue = NSColor(hex: 0x000099)
    let orange = NSColor(hex: 0xFE8F11)
    let center = NSPoint(x: rect.midX, y: rect.midY)
    let orbit = NSBezierPath(ovalIn: NSRect(x: center.x - rect.width * 0.20, y: center.y - rect.height * 0.30, width: rect.width * 0.40, height: rect.height * 0.60))
    blue.withAlphaComponent(0.22).setStroke()
    orbit.lineWidth = max(1, size * 0.009)
    orbit.stroke()

    let core = NSBezierPath(ovalIn: NSRect(x: center.x - size * 0.030, y: center.y - size * 0.030, width: size * 0.060, height: size * 0.060))
    orange.setFill()
    core.fill()

    for angle in stride(from: 0.0, to: 360.0, by: 120.0) {
        let radians = angle * .pi / 180.0
        let point = NSPoint(x: center.x + cos(radians) * rect.width * 0.23, y: center.y + sin(radians) * rect.height * 0.33)
        let node = NSBezierPath(ovalIn: NSRect(x: point.x - size * 0.017, y: point.y - size * 0.017, width: size * 0.034, height: size * 0.034))
        blue.setFill()
        node.fill()
    }
}

private func drawCheckGlyph(in rect: NSRect, size: CGFloat) {
    let check = NSBezierPath()
    check.move(to: NSPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.47))
    check.line(to: NSPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.29))
    check.line(to: NSPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.70))
    check.lineWidth = max(2, size * 0.028)
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    NSColor(hex: 0x84C041).setStroke()
    check.stroke()
}

private func drawLine(from start: NSPoint, to end: NSPoint, color: NSColor, width: CGFloat) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = max(1, width)
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()
}

private enum IconError: Error {
    case bitmapCreationFailed
    case graphicsContextFailed
    case pngEncodingFailed
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255.0,
            green: CGFloat((hex >> 8) & 0xff) / 255.0,
            blue: CGFloat(hex & 0xff) / 255.0,
            alpha: 1.0
        )
    }
}
