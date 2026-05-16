import Foundation
import SwiftUI

struct ChartTraceLabel: View {
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(WorthlineTheme.textPrimary)
                .monospacedDigit()
            Text(subtitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WorthlineTheme.textSecondary)
                .monospacedDigit()
        }
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.38), lineWidth: 0.9)
        }
        .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
    }
}

extension Array {
    func nearest(to targetDate: Date, by date: KeyPath<Element, Date>) -> Element? {
        self.min { first, second in
            abs(first[keyPath: date].timeIntervalSince(targetDate)) < abs(second[keyPath: date].timeIntervalSince(targetDate))
        }
    }
}
