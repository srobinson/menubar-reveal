// Renders an SVG: swift scripts/render-svg.swift <svg> <output>
//   <output>.icns  an app icon with every iconset size
//   <output>.png   the SVG's own size at 1x, plus <output>@2x.png
import AppKit

struct RenderError: Error, CustomStringConvertible {
    let description: String
}

let arguments = CommandLine.arguments
guard arguments.count == 3, let source = NSImage(contentsOfFile: arguments[1]) else {
    FileHandle.standardError.write(Data("usage: render-svg.swift <svg> <output.icns|output.png>\n".utf8))
    exit(1)
}
let output = URL(fileURLWithPath: arguments[2])

// Draws the SVG into a width x height pixel PNG tagged as `scale`x, so a 2x render reads as 144 dpi.
func writePNG(width: Int, height: Int, scale: Int, to url: URL) throws {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { throw RenderError(description: "could not make a \(width) x \(height) bitmap") }
    bitmap.size = NSSize(width: width / scale, height: height / scale)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(in: NSRect(origin: .zero, size: bitmap.size))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw RenderError(description: "could not encode \(url.lastPathComponent)")
    }
    try png.write(to: url)
}

// Renders every iconset size into a temporary iconset, which the defer removes however this returns, and converts it
// with iconutil. Returns iconutil's exit status.
func writeIcns(to url: URL) throws -> Int32 {
    let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(getpid()).iconset")
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: iconset) }
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let pixels = points * scale
            let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
            try writePNG(width: pixels, height: pixels, scale: scale, to: iconset.appendingPathComponent(name))
        }
    }
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", url.path]
    try iconutil.run()
    iconutil.waitUntilExit()
    return iconutil.terminationStatus
}

do {
    switch output.pathExtension {
    case "icns":
        exit(try writeIcns(to: output))
    case "png":
        let base = output.deletingPathExtension().path
        for scale in [1, 2] {
            let url = URL(fileURLWithPath: scale == 1 ? "\(base).png" : "\(base)@\(scale)x.png")
            try writePNG(
                width: Int(source.size.width) * scale, height: Int(source.size.height) * scale, scale: scale, to: url)
        }
    default:
        throw RenderError(description: "output must end in .icns or .png")
    }
} catch {
    FileHandle.standardError.write(Data("render-svg.swift: \(error)\n".utf8))
    exit(1)
}
