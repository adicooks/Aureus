import AppKit
import SwiftUI

enum WorthlineTheme {
    static let accent = Color(red: 0.04, green: 0.45, blue: 0.54)
    static let accentStrong = Color(red: 0.02, green: 0.35, blue: 0.42)
    static let accentSoft = Color(red: 0.04, green: 0.45, blue: 0.54).opacity(0.13)
    static let positive = Color(red: 0.05, green: 0.58, blue: 0.36)
    static let negative = Color(red: 0.86, green: 0.19, blue: 0.24)
    static let warning = Color(red: 0.88, green: 0.50, blue: 0.08)

    static let background = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.012, green: 0.014, blue: 0.017, alpha: 1) : NSColor(red: 0.957, green: 0.960, blue: 0.952, alpha: 1)
    })

    static let cardBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.040, green: 0.044, blue: 0.050, alpha: 1) : NSColor.white.withAlphaComponent(0.94)
    })

    static let sidebarBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.022, green: 0.026, blue: 0.031, alpha: 1) : NSColor(red: 0.920, green: 0.932, blue: 0.925, alpha: 1)
    })

    static let fieldBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDarkMode ? NSColor(red: 0.060, green: 0.066, blue: 0.075, alpha: 1) : NSColor(red: 0.982, green: 0.984, blue: 0.978, alpha: 1)
    })

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let border = Color(nsColor: .separatorColor).opacity(0.38)
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
