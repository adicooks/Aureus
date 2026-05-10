import AppKit

enum AppIconRenderer {
    static func makeIcon(size: CGFloat = 1024) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        let bounds = NSRect(x: 0, y: 0, width: size, height: size)
        NSColor(red: 0.055, green: 0.058, blue: 0.061, alpha: 1).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.06, dy: size * 0.06), xRadius: size * 0.20, yRadius: size * 0.20).fill()

        let glowRect = bounds.insetBy(dx: size * 0.17, dy: size * 0.17)
        let glowPath = NSBezierPath(ovalIn: glowRect)
        NSColor(red: 0.10, green: 0.78, blue: 0.50, alpha: 0.08).setFill()
        glowPath.fill()

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

        let ringRect = bounds.insetBy(dx: size * 0.11, dy: size * 0.11)
        NSColor.white.withAlphaComponent(0.08).setStroke()
        let ring = NSBezierPath(roundedRect: ringRect, xRadius: size * 0.16, yRadius: size * 0.16)
        ring.lineWidth = size * 0.012
        ring.stroke()

        return image
    }
}
