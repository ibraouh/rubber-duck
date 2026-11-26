// Draws the app icon in its three iOS appearances (light, dark, tinted) as
// 1024×1024 PNGs. Run from the project folder:
//
//   swift scripts/make-icon.swift IdeaApp/Assets.xcassets/AppIcon.appiconset
//
// The design: a speech bubble (the conversation) with a branching mark inside
// (an idea splitting into better ones) and a spark on the stronger branch.
// Shapes are drawn by hand: SF Symbols may not be used in app icons.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

struct Palette {
    var background: [CGColor]
    var bubble: CGColor
    var branch: CGColor
    var strongNode: CGColor
    var spark: CGColor
    var shadow: CGColor?
    var highlight: Bool
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let light = Palette(
    background: [rgb(0xFFC046), rgb(0xFF8A3D), rgb(0xF2585B)],
    bubble: rgb(0xFFFFFF),
    branch: rgb(0xFF7A3D),
    strongNode: rgb(0xF2585B),
    spark: rgb(0xFFB52E),
    shadow: rgb(0x8A2A10, 0.28),
    highlight: true
)

let dark = Palette(
    background: [rgb(0x2C2C2E), rgb(0x121214)],
    bubble: rgb(0x3A3A3C),
    branch: rgb(0xFF8A3D),
    strongNode: rgb(0xFF6B5E),
    spark: rgb(0xFFC046),
    shadow: rgb(0x000000, 0.45),
    highlight: false
)

// Tinted icons are read as grayscale and colored by the system.
let tinted = Palette(
    background: [rgb(0x000000), rgb(0x000000)],
    bubble: rgb(0xFFFFFF),
    branch: rgb(0x2A2A2A),
    strongNode: rgb(0x2A2A2A),
    spark: rgb(0x6A6A6A),
    shadow: nil,
    highlight: false
)

func draw(_ palette: Palette, to filename: String) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { fatalError("no context") }

    // Work in top-left coordinates.
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)
    let s = CGFloat(size)

    // Background: a diagonal gradient, plus a soft light in the top-left corner.
    let gradient = CGGradient(colorsSpace: space, colors: palette.background as CFArray, locations: nil)!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: s, y: s), options: [])
    if palette.highlight {
        let glow = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 220, y: 160), startRadius: 0,
                               endCenter: CGPoint(x: 220, y: 160), endRadius: 620, options: [])
    }

    // The speech bubble, with its tail at the bottom left.
    let bubbleRect = CGRect(x: 182, y: 226, width: 660, height: 492)
    let bubble = CGMutablePath()
    bubble.addRoundedRect(in: bubbleRect, cornerWidth: 160, cornerHeight: 160)
    // The tail starts inside the bubble so the two shapes join without a seam.
    let tail = CGMutablePath()
    tail.move(to: CGPoint(x: 300, y: 620))
    tail.addLine(to: CGPoint(x: 300, y: 700))
    tail.addCurve(to: CGPoint(x: 232, y: 826), control1: CGPoint(x: 300, y: 770), control2: CGPoint(x: 276, y: 806))
    tail.addCurve(to: CGPoint(x: 460, y: 712), control1: CGPoint(x: 336, y: 812), control2: CGPoint(x: 410, y: 766))
    tail.addLine(to: CGPoint(x: 460, y: 620))
    tail.closeSubpath()

    ctx.saveGState()
    if let shadow = palette.shadow {
        ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 46, color: shadow)
    }
    ctx.setFillColor(palette.bubble)
    // Fill the two shapes separately (they wind in opposite directions, so one
    // combined fill would cut a hole where they overlap); the layer gives them
    // one shared shadow.
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.addPath(bubble)
    ctx.fillPath()
    ctx.addPath(tail)
    ctx.fillPath()
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    // The branch: a stem that splits in two.
    let rootY: CGFloat = 610, forkY: CGFloat = 486
    let left = CGPoint(x: 404, y: 370), right = CGPoint(x: 620, y: 352)
    let branch = CGMutablePath()
    branch.move(to: CGPoint(x: 512, y: rootY))
    branch.addLine(to: CGPoint(x: 512, y: forkY))
    branch.addCurve(to: left, control1: CGPoint(x: 512, y: 430), control2: CGPoint(x: left.x, y: 440))
    branch.move(to: CGPoint(x: 512, y: forkY))
    branch.addCurve(to: right, control1: CGPoint(x: 512, y: 430), control2: CGPoint(x: right.x, y: 430))
    ctx.setStrokeColor(palette.branch)
    ctx.setLineWidth(38)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(branch)
    ctx.strokePath()

    // Nodes: the starting idea, the one that didn't work out, and the stronger one.
    func node(_ center: CGPoint, _ radius: CGFloat, _ color: CGColor) {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
    node(CGPoint(x: 512, y: rootY), 40, palette.branch)
    node(left, 40, palette.bubble)
    node(left, 40, palette.branch.copy(alpha: 0.4)!)
    node(right, 54, palette.strongNode)

    // A four-pointed spark next to the stronger idea.
    let c = CGPoint(x: 712, y: 300), r: CGFloat = 46, w: CGFloat = 12
    let spark = CGMutablePath()
    spark.move(to: CGPoint(x: c.x, y: c.y - r))
    spark.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + w, y: c.y - w))
    spark.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + w, y: c.y + w))
    spark.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - w, y: c.y + w))
    spark.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - w, y: c.y - w))
    ctx.setFillColor(palette.spark)
    ctx.addPath(spark)
    ctx.fillPath()

    guard let image = ctx.makeImage() else { fatalError("no image") }
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(filename)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("can't write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("can't finalize \(url.path)") }
    print(url.path)
}

try draw(light, to: "AppIcon.png")
try draw(dark, to: "AppIcon-Dark.png")
try draw(tinted, to: "AppIcon-Tinted.png")
