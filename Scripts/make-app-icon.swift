import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: make-app-icon.swift <output.icns>\n".utf8))
    exit(64)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let fileManager = FileManager.default
let iconsetURL = outputURL
    .deletingPathExtension()
    .appendingPathExtension("iconset")

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconVariant {
    let pixels: Int
    let filename: String
}

let variants = [
    IconVariant(pixels: 16, filename: "icon_16x16.png"),
    IconVariant(pixels: 32, filename: "icon_16x16@2x.png"),
    IconVariant(pixels: 32, filename: "icon_32x32.png"),
    IconVariant(pixels: 64, filename: "icon_32x32@2x.png"),
    IconVariant(pixels: 128, filename: "icon_128x128.png"),
    IconVariant(pixels: 256, filename: "icon_128x128@2x.png"),
    IconVariant(pixels: 256, filename: "icon_256x256.png"),
    IconVariant(pixels: 512, filename: "icon_256x256@2x.png"),
    IconVariant(pixels: 512, filename: "icon_512x512.png"),
    IconVariant(pixels: 1024, filename: "icon_512x512@2x.png")
]

for variant in variants {
    let image = renderIcon(size: CGFloat(variant.pixels))
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        FileHandle.standardError.write(Data("Unable to render \(variant.filename)\n".utf8))
        exit(1)
    }
    try png.write(to: iconsetURL.appendingPathComponent(variant.filename), options: .atomic)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    FileHandle.standardError.write(Data("iconutil failed with status \(process.terminationStatus)\n".utf8))
    exit(process.terminationStatus)
}

try? fileManager.removeItem(at: iconsetURL)

func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor(red: 0.055, green: 0.058, blue: 0.061, alpha: 1).setFill()
    NSBezierPath(
        roundedRect: bounds.insetBy(dx: size * 0.06, dy: size * 0.06),
        xRadius: size * 0.20,
        yRadius: size * 0.20
    ).fill()

    NSColor(red: 0.10, green: 0.78, blue: 0.50, alpha: 0.08).setFill()
    NSBezierPath(ovalIn: bounds.insetBy(dx: size * 0.17, dy: size * 0.17)).fill()

    let dotSize = size * 0.064
    let gap = size * 0.034
    let gridSize = dotSize * 4 + gap * 3
    let startX = (size - gridSize) / 2
    let startY = (size - gridSize) / 2

    for row in 0..<4 {
        for column in 0..<4 {
            let index = row * 4 + column
            let rect = NSRect(
                x: startX + CGFloat(column) * (dotSize + gap),
                y: startY + CGFloat(3 - row) * (dotSize + gap),
                width: dotSize,
                height: dotSize
            )
            let isAccent = [0, 3, 5, 10, 12, 15].contains(index)
            let color = isAccent
                ? NSColor(red: 0.12, green: 0.78, blue: 0.50, alpha: 1)
                : NSColor(white: 0.92, alpha: 1)
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    NSColor.white.withAlphaComponent(0.08).setStroke()
    let ring = NSBezierPath(
        roundedRect: bounds.insetBy(dx: size * 0.11, dy: size * 0.11),
        xRadius: size * 0.16,
        yRadius: size * 0.16
    )
    ring.lineWidth = max(1, size * 0.012)
    ring.stroke()

    return image
}
