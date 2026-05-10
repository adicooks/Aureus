import AppKit
import SwiftUI

enum WorthlineTheme {
    static let accent = Color(red: 0.12, green: 0.78, blue: 0.50)
    static let accentStrong = Color(red: 0.08, green: 0.58, blue: 0.38)
    static let accentSoft = Color(red: 0.12, green: 0.78, blue: 0.50).opacity(0.14)
    static let positive = Color(red: 0.12, green: 0.78, blue: 0.50)
    static let negative = Color(red: 0.95, green: 0.25, blue: 0.32)
    static let warning = Color(red: 0.96, green: 0.68, blue: 0.17)

    static let background = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.035, green: 0.039, blue: 0.041, alpha: 1) : NSColor(red: 0.957, green: 0.960, blue: 0.952, alpha: 1)
    })

    static let cardBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.085, green: 0.095, blue: 0.098, alpha: 1) : NSColor.white.withAlphaComponent(0.96)
    })

    static let sidebarBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.105, green: 0.105, blue: 0.112, alpha: 1) : NSColor(red: 0.920, green: 0.932, blue: 0.925, alpha: 1)
    })

    static let fieldBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.125, green: 0.132, blue: 0.135, alpha: 1) : NSColor(red: 0.982, green: 0.984, blue: 0.978, alpha: 1)
    })

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let border = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.20, green: 0.22, blue: 0.22, alpha: 1) : NSColor.separatorColor
    }).opacity(0.70)
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

    func aureusFieldStyle() -> some View {
        textFieldStyle(.plain)
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(WorthlineTheme.fieldBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(WorthlineTheme.border, lineWidth: 0.8)
            }
    }
}
