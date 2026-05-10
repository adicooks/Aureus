import AppKit
import SwiftUI

enum WorthlineTheme {
    static let accent = Color(red: 0.43, green: 0.25, blue: 0.94)
    static let accentSoft = Color(red: 0.43, green: 0.25, blue: 0.94).opacity(0.14)
    static let positive = Color(red: 0.12, green: 0.72, blue: 0.42)
    static let negative = Color(red: 0.94, green: 0.25, blue: 0.31)
    static let warning = Color(red: 0.96, green: 0.58, blue: 0.16)

    static let background = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.035, green: 0.047, blue: 0.063, alpha: 1) : NSColor(red: 0.965, green: 0.968, blue: 0.978, alpha: 1)
    })

    static let cardBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.075, green: 0.09, blue: 0.115, alpha: 1) : NSColor.white.withAlphaComponent(0.92)
    })

    static let sidebarBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.055, green: 0.071, blue: 0.092, alpha: 1) : NSColor(red: 0.925, green: 0.925, blue: 0.975, alpha: 1)
    })

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let border = Color(nsColor: .separatorColor).opacity(0.52)
}

private extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

extension View {
    func premiumPageBackground() -> some View {
        background(WorthlineTheme.background)
    }
}

