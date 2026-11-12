// Draws the Station sign app icon (logo/round-4-shortlist.html) as a 1024 px PNG.
// Run from the repo root:  swift tools/make-app-icon.swift
// Temporary icon: the final one is meant to be rebuilt as layers in Apple's Icon Composer.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024, s = CGFloat(size) / 100          // the design is drawn on a 100 × 100 grid
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!     // no transparency: App Store rule

func color(_ hex: UInt32) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 0xff) / 255, CGFloat((hex >> 8) & 0xff) / 255,
                                            CGFloat(hex & 0xff) / 255, 1])!
}
/// Design coordinates have y going down; CoreGraphics goes up.
func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: x * s, y: (100 - y - h) * s, width: w * s, height: h * s)
}
func text(_ string: String, x: CGFloat, baseline: CGFloat, size: CGFloat, kern: CGFloat, fill: CGColor, centered: Bool = false) {
    let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, size * s, nil)
    let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: fill,
                                  kCTKernAttributeName: kern * s]
    let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, string as CFString, attrs as CFDictionary)!)
    let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) - kern * s
    ctx.textPosition = CGPoint(x: centered ? x * s - width / 2 : x * s, y: (100 - baseline) * s)
    CTLineDraw(line, ctx)
}

ctx.setFillColor(color(0x111111)); ctx.fill(rect(0, 0, 100, 100))
ctx.setFillColor(color(0xffffff)); ctx.fill(rect(11, 16, 78, 2.2))
text("Bus", x: 10, baseline: 58, size: 38, kern: -1.5, fill: color(0xffffff))

let badges: [(String, UInt32, UInt32)] = [("A", 0xf7b6d2, 0x1c1c1e), ("E", 0xCD5C5C, 0xffffff), ("F", 0x3CB371, 0x1c1c1e)]
for (i, (letter, fill, ink)) in badges.enumerated() {
    let x = 11 + CGFloat(i) * 19
    ctx.setFillColor(color(fill))
    ctx.addPath(CGPath(roundedRect: rect(x, 69, 15, 15), cornerWidth: 3.6 * s, cornerHeight: 3.6 * s, transform: nil))
    ctx.fillPath()
    text(letter, x: x + 7.5, baseline: 80.5, size: 10.5, kern: 0, fill: color(ink), centered: true)
}

let out = URL(fileURLWithPath: "ios/Bussin/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(out.path)") }
print("wrote \(out.path)")
