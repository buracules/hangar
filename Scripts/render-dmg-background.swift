// Renders Scripts/dmg/background.svg into the 1x + 2x background.tiff dmgbuild uses.
//
//   swift Scripts/render-dmg-background.swift
import AppKit

let folder = URL(fileURLWithPath: "Scripts/dmg")
let size = NSSize(width: 660, height: 420)
guard let svg = NSImage(contentsOf: folder.appendingPathComponent("background.svg")) else {
  fatalError("background.svg could not be read")
}

/// The SVG drawn at `scale`, as a bitmap whose point size stays 660×420.
func bitmap(scale: CGFloat) -> NSBitmapImageRep {
  let pixels = NSSize(width: size.width * scale, height: size.height * scale)
  guard
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
  else { fatalError("could not make a bitmap") }
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  svg.draw(in: NSRect(origin: .zero, size: pixels))
  NSGraphicsContext.restoreGraphicsState()
  rep.size = size
  return rep
}

let image = NSImage(size: size)
image.addRepresentation(bitmap(scale: 1))
image.addRepresentation(bitmap(scale: 2))
guard let tiff = image.tiffRepresentation(using: .lzw, factor: 0) else {
  fatalError("could not encode the TIFF")
}
try tiff.write(to: folder.appendingPathComponent("background.tiff"))
print("wrote Scripts/dmg/background.tiff")
