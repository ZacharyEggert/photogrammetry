// ponytail: draws the icon in AppKit instead of shipping a designer asset.
// Run: swift tools/makeicon.swift  -> Photogrammetry.icns
import AppKit

let canvas = 1024.0, inset = 100.0, radius = 185.0
let img = NSImage(size: NSSize(width: canvas, height: canvas))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let rect = NSRect(x: inset, y: inset, width: canvas - 2*inset, height: canvas - 2*inset)
let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

ctx.saveGState()
squircle.addClip()
let grad = NSGradient(colors: [NSColor(srgbRed: 0.35, green: 0.45, blue: 0.95, alpha: 1),
                              NSColor(srgbRed: 0.55, green: 0.20, blue: 0.75, alpha: 1)])!
grad.draw(in: rect, angle: -90)
ctx.restoreGState()

let cfg = NSImage.SymbolConfiguration(pointSize: 440, weight: .light)
if let sym = NSImage(systemSymbolName: "cube.transparent", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let tinted = NSImage(size: sym.size, flipped: false) { r in
        sym.draw(in: r); NSColor.white.set(); r.fill(using: .sourceAtop); return true
    }
    let s = tinted.size
    tinted.draw(in: NSRect(x: (canvas - s.width)/2, y: (canvas - s.height)/2, width: s.width, height: s.height))
}
img.unlockFocus()

let png = NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: "icon-1024.png"))

// iconset -> icns
let fm = FileManager.default
try? fm.removeItem(atPath: "icon.iconset")
try fm.createDirectory(atPath: "icon.iconset", withIntermediateDirectories: true)
for (px, name) in [(16,"16x16"),(32,"16x16@2x"),(32,"32x32"),(64,"32x32@2x"),(128,"128x128"),
                   (256,"128x128@2x"),(256,"256x256"),(512,"256x256@2x"),(512,"512x512"),(1024,"512x512@2x")] {
    let p = Process()
    p.launchPath = "/usr/bin/sips"
    p.arguments = ["-z", "\(px)", "\(px)", "icon-1024.png", "--out", "icon.iconset/icon_\(name).png"]
    p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
    try p.run(); p.waitUntilExit()
}
let icnsProc = Process()
icnsProc.launchPath = "/usr/bin/iconutil"
icnsProc.arguments = ["-c", "icns", "icon.iconset", "-o", "Resources/AppIcon.icns"]
try icnsProc.run(); icnsProc.waitUntilExit()
try? fm.removeItem(atPath: "icon.iconset")
