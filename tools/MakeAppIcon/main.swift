// Renders App/Assets.xcassets/AppIcon.appiconset — the iPhone app icon.
//
// Same design as the macOS app (jev-jarvis/packaging/make_icon.py): bright green
// tile, white "J", speech-bubble tail. Two deliberate differences:
//
//  1. Full bleed. The macOS icon is inset ~9% with pre-rounded corners because that
//     is how Mac icons are drawn; iOS masks the corners itself, so an inset icon
//     would show the corners of the canvas around it.
//  2. No alpha channel. App Store submission rejects icons with alpha (ITMS-90717),
//     and the home screen renders transparent pixels as black.
//
// Proportions are measured against the green tile rather than the canvas (the Mac
// script's numbers divided by its 0.82 body side), so the "J" and the tail sit at
// the same place on both platforms.
//
// Usage: swiftc -O -o /tmp/makeappicon tools/MakeAppIcon/main.swift && /tmp/makeappicon <appiconset dir>

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let green = CGColor(red: 0.027, green: 0.757, blue: 0.376, alpha: 1.0)  // #07C160

// Ratios of the green tile's side, from the macOS script.
let jFontRatio = 0.682927
// Where the "J" ink box lands, as a fraction of the tile measured from the bottom.
// Taken from the shipped macOS render rather than derived from font metrics: AppKit
// lays the line out with leading that CTLine does not report, so reproducing the
// macOS script's drawInRect rect put the mark 12% of the tile too low.
let jInkCenterYRatio = 0.50342
let tailXRatio = 0.30
let tailYRatio = 0.20
let tailHalfRatio = 0.121951
let tailDXRatio = 0.170732
let tailDownRatio = 0.048780

func render(px: Int) -> CGImage? {
    let side = CGFloat(px)
    // 32-bit RGB with an ignored fourth byte — CoreGraphics has no 24-bit context.
    // `noneSkipLast` still yields a PNG without an alpha channel; see the note above.
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }

    ctx.setFillColor(green)
    ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

    // the "J" mark: centered horizontally by advance width (same as the macOS script's
    // drawInRect), positioned vertically by its ink box.
    let font = NSFont.boldSystemFont(ofSize: side * jFontRatio)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "J", attributes: attrs))
    let advance = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textPosition = CGPoint(x: side / 2 - advance / 2, y: side * jInkCenterYRatio - ink.midY)
    CTLineDraw(line, ctx)

    // speak-bubble tail: a small white notch on the lower-left of the mark, so the
    // icon reads as "conversation" rather than a plain letter tile
    let tx = side * tailXRatio
    let ty = side * tailYRatio
    ctx.beginPath()
    ctx.move(to: CGPoint(x: tx, y: ty + side * tailHalfRatio))
    ctx.addLine(to: CGPoint(x: tx + side * tailDXRatio, y: ty + side * tailHalfRatio))
    ctx.addLine(to: CGPoint(x: tx, y: ty - side * tailDownRatio))
    ctx.closePath()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fillPath()

    return ctx.makeImage()
}

func write(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "MakeAppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot create \(url.path)"])
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "MakeAppIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "cannot write \(url.path)"])
    }
}

// pixel sizes the asset catalog entry points at (iPhone only, TARGETED_DEVICE_FAMILY=1)
let sizes = [40, 60, 58, 87, 80, 120, 180, 1024]

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1]
                                                                  : "App/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

_ = NSApplication.shared  // AppKit drawing wants an app object present, even headless

for px in sizes {
    guard let image = render(px: px) else {
        FileHandle.standardError.write("render \(px) failed\n".data(using: .utf8)!)
        exit(1)
    }
    try write(image, to: outDir.appendingPathComponent("icon-\(px).png"))
}
print("wrote \(sizes.count) pngs to \(outDir.path)")
