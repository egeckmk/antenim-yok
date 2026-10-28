import AppKit

// usage: swift render-preview.swift <background.svg> <foreground.svg> <out.png>
let args = CommandLine.arguments
let size = CGSize(width: 1024, height: 1024)
let bg = NSImage(contentsOfFile: args[1])!
let fg = NSImage(contentsOfFile: args[2])!
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let rect = CGRect(origin: .zero, size: size)
NSBezierPath(roundedRect: rect, xRadius: 230, yRadius: 230).addClip()
bg.draw(in: rect)
fg.draw(in: rect)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[3]))
