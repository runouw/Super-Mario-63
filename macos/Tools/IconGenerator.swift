import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: IconGenerator OUTPUT.png\n", stderr)
    exit(64)
}

let canvasSize = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvasSize)
image.lockFocus()

guard let context = NSGraphicsContext.current else {
    fputs("could not create graphics context\n", stderr)
    exit(1)
}
context.imageInterpolation = .high

let outerRect = NSRect(x: 24, y: 24, width: 976, height: 976)
let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 220, yRadius: 220)
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.15, green: 0.62, blue: 1.0, alpha: 1.0),
    NSColor(calibratedRed: 0.07, green: 0.25, blue: 0.72, alpha: 1.0),
])!
background.draw(in: outerPath, angle: -90)

NSGraphicsContext.saveGraphicsState()
outerPath.addClip()

let glow = NSGradient(colorsAndLocations:
    (NSColor(calibratedRed: 1.0, green: 0.93, blue: 0.25, alpha: 0.70), 0.0),
    (NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.08, alpha: 0.0), 1.0)
)!
glow.draw(fromCenter: NSPoint(x: 512, y: 530), radius: 40, toCenter: NSPoint(x: 512, y: 530), radius: 440, options: [])

let cloudColor = NSColor(calibratedWhite: 1.0, alpha: 0.20)
cloudColor.setFill()
for cloud in [
    NSRect(x: -90, y: 120, width: 430, height: 160),
    NSRect(x: 700, y: 710, width: 410, height: 145),
] {
    NSBezierPath(roundedRect: cloud, xRadius: 80, yRadius: 80).fill()
}

NSGraphicsContext.restoreGraphicsState()

let starCenter = NSPoint(x: 512, y: 548)
let star = NSBezierPath()
for pointIndex in 0..<10 {
    let angle = (Double(pointIndex) * .pi / 5.0) + (.pi / 2.0)
    let radius = pointIndex.isMultiple(of: 2) ? 330.0 : 150.0
    let point = NSPoint(
        x: starCenter.x + CGFloat(cos(angle) * radius),
        y: starCenter.y + CGFloat(sin(angle) * radius)
    )
    pointIndex == 0 ? star.move(to: point) : star.line(to: point)
}
star.close()

let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.36)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -22)
shadow.set()
NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.05, alpha: 1.0).setFill()
star.fill()
NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.45, alpha: 1.0).setStroke()
star.lineWidth = 22
star.stroke()

NSShadow().set()
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let text = "63" as NSString
let textRect = NSRect(x: 190, y: 350, width: 644, height: 390)
text.draw(in: textRect, withAttributes: [
    .font: NSFont.systemFont(ofSize: 310, weight: .black),
    .foregroundColor: NSColor(calibratedRed: 0.91, green: 0.10, blue: 0.10, alpha: 1.0),
    .strokeColor: NSColor.white,
    .strokeWidth: -7.0,
    .paragraphStyle: paragraph,
])

NSColor(calibratedWhite: 1.0, alpha: 0.45).setStroke()
outerPath.lineWidth = 18
outerPath.stroke()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("could not encode app icon\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
