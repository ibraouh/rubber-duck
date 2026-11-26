// Draws the app icon in its three iOS appearances (light, dark, tinted) as
// 1024×1024 PNGs. Run from the project folder:
//
//   swift scripts/make-icon.swift IdeaApp/Assets.xcassets/AppIcon.appiconset
//
// The design: a simple rubber duck, for the app's name.
// Rubber-duck debugging is explaining a problem out loud until it makes sense,
// which is what you do with an idea here. Shapes are drawn by hand: SF Symbols
// may not be used in app icons.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

struct Palette {
    var sky: [CGColor]
    var duck: CGColor
    var wing: CGColor
    var beak: CGColor
    var eye: CGColor
    var glint: CGColor
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
    sky: [rgb(0xCDEBFF), rgb(0x8FCBFA)],
    duck: rgb(0xFFD23F),
    wing: rgb(0xF5B400),
    beak: rgb(0xFF8A1F),
    eye: rgb(0x1C1C1E),
    glint: rgb(0xFFFFFF)
)

let dark = Palette(
    sky: [rgb(0x2C2C2E), rgb(0x121214)],
    duck: rgb(0xFFCC2E),
    wing: rgb(0xE5A600),
    beak: rgb(0xFF8A1F),
    eye: rgb(0x1C1C1E),
    glint: rgb(0xFFFFFF)
)

// Tinted icons are read as grayscale and colored by the system.
let tinted = Palette(
    sky: [rgb(0x000000), rgb(0x000000)],
    duck: rgb(0xFFFFFF),
    wing: rgb(0xBDBDBD),
    beak: rgb(0x8A8A8A),
    eye: rgb(0x000000),
    glint: rgb(0xFFFFFF)
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

    // Sky: a soft vertical gradient.
    let sky = CGGradient(colorsSpace: space, colors: palette.sky as CFArray, locations: nil)!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: s), options: [])

    func circle(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    // Center the duck on the canvas (it spans about x 168–895, y 248–850).
    ctx.translateBy(x: -20, y: -37)

    // The beak goes first, so the head covers its base.
    let beak = CGMutablePath()
    beak.move(to: CGPoint(x: 300, y: 372))
    beak.addQuadCurve(to: CGPoint(x: 168, y: 414), control: CGPoint(x: 220, y: 360))
    beak.addQuadCurve(to: CGPoint(x: 300, y: 478), control: CGPoint(x: 196, y: 476))
    beak.closeSubpath()
    ctx.setFillColor(palette.beak)
    ctx.addPath(beak)
    ctx.fillPath()

    // Body, upturned tail and head, in one color. Each shape is filled on its
    // own so overlaps never cancel out.
    ctx.setFillColor(palette.duck)
    ctx.fillEllipse(in: CGRect(x: 250, y: 450, width: 620, height: 400))
    let tail = CGMutablePath()
    tail.move(to: CGPoint(x: 640, y: 500))
    tail.addQuadCurve(to: CGPoint(x: 880, y: 430), control: CGPoint(x: 790, y: 500))
    tail.addQuadCurve(to: CGPoint(x: 862, y: 660), control: CGPoint(x: 912, y: 560))
    tail.addLine(to: CGPoint(x: 640, y: 660))
    tail.closeSubpath()
    ctx.addPath(tail)
    ctx.fillPath()
    ctx.fillEllipse(in: circle(CGPoint(x: 400, y: 400), 152))

    // The wing.
    let wing = CGMutablePath()
    wing.move(to: CGPoint(x: 480, y: 610))
    wing.addCurve(to: CGPoint(x: 748, y: 590), control1: CGPoint(x: 540, y: 720), control2: CGPoint(x: 690, y: 716))
    wing.addCurve(to: CGPoint(x: 480, y: 610), control1: CGPoint(x: 680, y: 548), control2: CGPoint(x: 548, y: 552))
    wing.closeSubpath()
    ctx.setFillColor(palette.wing)
    ctx.addPath(wing)
    ctx.fillPath()

    // The eye, with a glint.
    ctx.setFillColor(palette.eye)
    ctx.fillEllipse(in: circle(CGPoint(x: 362, y: 366), 27))
    ctx.setFillColor(palette.glint)
    ctx.fillEllipse(in: circle(CGPoint(x: 371, y: 357), 9))

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
