import Charts
import SwiftUI

enum TimeRange: String, CaseIterable, Identifiable {
    case oneDay = "1D"
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case oneYear = "1Y"
    case all = "ALL"

    var id: String { rawValue }

    func contains(_ date: Date, relativeTo now: Date = .now) -> Bool {
        switch self {
        case .oneDay:
            return date >= Calendar.current.date(byAdding: .day, value: -1, to: now) ?? date
        case .oneWeek:
            return date >= Calendar.current.date(byAdding: .day, value: -7, to: now) ?? date
        case .oneMonth:
            return date >= Calendar.current.date(byAdding: .month, value: -1, to: now) ?? date
        case .threeMonths:
            return date >= Calendar.current.date(byAdding: .month, value: -3, to: now) ?? date
        case .oneYear:
            return date >= Calendar.current.date(byAdding: .year, value: -1, to: now) ?? date
        case .all:
            return true
        }
    }
}

struct SectionCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(WorthlineTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(WorthlineTheme.border, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }
}

typealias AureusCard = SectionCard

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(WorthlineTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(WorthlineTheme.textSecondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(WorthlineTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(WorthlineTheme.border, lineWidth: 0.8)
                    }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var detail: String?
    var symbol: String
    var tint: Color = WorthlineTheme.accent

    var body: some View {
        SectionCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 30, height: 30)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WorthlineTheme.textSecondary)
                    Text(value)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if let detail {
                        Text(detail)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(tint)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

typealias MetricCard = StatCard

struct ChartCard<Content: View>: View {
    let title: String
    var subtitle: String?
    var trailing: AnyView?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
        self.content = content()
    }

    init<Trailing: View>(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
        self.content = content()
    }

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    SectionHeader(title: title, subtitle: subtitle)
                    if let trailing {
                        trailing
                    }
                }
                content
            }
        }
    }
}

struct TimeRangePicker: View {
    @Binding var selection: TimeRange

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        selection = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(selection == range ? Color.white.opacity(0.16) : Color.secondary.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(selection == range ? Color.white.opacity(0.45) : Color.clear, lineWidth: 0.8)
                        }
                        .foregroundStyle(selection == range ? WorthlineTheme.textPrimary : WorthlineTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
    }
}

struct FilterPills<Option: Hashable, Label: View>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> Label

    var body: some View {
        HStack(spacing: 7) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selection = option
                    }
                } label: {
                    label(option)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selection == option ? Color.white.opacity(0.16) : Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(selection == option ? Color.white.opacity(0.40) : Color.clear, lineWidth: 0.8)
                        }
                        .foregroundStyle(selection == option ? WorthlineTheme.textPrimary : WorthlineTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.callout)
                .foregroundStyle(WorthlineTheme.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(WorthlineTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(WorthlineTheme.fieldBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(WorthlineTheme.border, lineWidth: 0.8)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let symbol {
                    Image(systemName: symbol)
                }
            }
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .frame(minHeight: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(nsColor: .windowBackgroundColor))
        .background(Color.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.20), radius: 10, y: 5)
    }
}

struct SecondaryButton: View {
    let title: String
    var symbol: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let symbol {
                    Image(systemName: symbol)
                }
            }
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .frame(minHeight: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(WorthlineTheme.textPrimary)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(WorthlineTheme.border, lineWidth: 0.8)
        }
    }
}

struct GainLossText: View {
    let amount: Double
    var percent: Double?
    var compact = false

    private var tint: Color {
        amount >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: amount >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text(amount, format: Formatters.currency)
                .monospacedDigit()
            if let percent {
                Text(percent, format: Formatters.percent)
                    .monospacedDigit()
                    .foregroundStyle(tint.opacity(0.82))
            }
        }
        .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
        .foregroundStyle(tint)
    }
}

struct AllocationDonutChart: View {
    let slices: [AllocationSlice]

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Value", slice.value),
                innerRadius: .ratio(0.64),
                angularInset: 1.8
            )
            .foregroundStyle(slice.kind.tint)
            .cornerRadius(4)
        }
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let frame = proxy.plotFrame {
                    let rect = geometry[frame]
                    VStack(spacing: 2) {
                        Text(slices.reduce(0) { $0 + $1.value }, format: Formatters.currency)
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text("Total")
                            .font(.caption2)
                            .foregroundStyle(WorthlineTheme.textSecondary)
                    }
                    .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }
}

struct AssetIcon: View {
    let holding: Holding

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(holding.kind.tint.opacity(0.14))

            if let logoURL = holding.logoURL, let url = URL(string: logoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(5)
                    default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: 34, height: 34)
    }

    private var initialsView: some View {
        Text(initials)
            .font(.caption.weight(.bold))
            .foregroundStyle(holding.kind.tint)
    }

    private var initials: String {
        let source = holding.ticker.isEmpty ? holding.name : holding.ticker
        return String(source.prefix(2)).uppercased()
    }
}

struct AssetRow: View {
    let metric: HoldingMetrics
    var action: (() -> Void)?
    @State private var hovering = false

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                AssetIcon(holding: metric.holding)
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.holding.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(metric.holding.displayTicker)
                        .font(.caption)
                        .foregroundStyle(WorthlineTheme.textSecondary)
                }
                Spacer()
                GainLossText(amount: metric.gainLoss, percent: metric.gainLossPercent, compact: true)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .background(hovering ? Color.secondary.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbol: String
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(WorthlineTheme.accent)
                .frame(width: 68, height: 68)
                .background(WorthlineTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(WorthlineTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 390)
            if let buttonTitle, let action {
                PrimaryButton(title: buttonTitle, symbol: "plus", action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(42)
    }
}

struct MarketStatusCard: View {
    let holdings: [Holding]
    let isRefreshing: Bool
    let refreshAction: () async -> Void

    private var isMarketOpen: Bool {
        let components = Calendar.current.dateComponents([.weekday, .hour, .minute], from: .now)
        guard let weekday = components.weekday, let hour = components.hour, let minute = components.minute else { return false }
        let minutes = hour * 60 + minute
        return (2...6).contains(weekday) && minutes >= 570 && minutes < 960
    }

    private var lastUpdated: Date? {
        holdings.compactMap(\.lastPriceUpdate).max()
    }

    var body: some View {
        SectionCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Market Status")
                            .font(.caption.weight(.semibold))
                        Label(isMarketOpen ? "Market Open" : "Market Closed", systemImage: "circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isMarketOpen ? WorthlineTheme.positive : WorthlineTheme.warning)
                    }
                    Spacer()
                }
                HStack {
                    Text("Last Updated")
                        .foregroundStyle(WorthlineTheme.textSecondary)
                    Spacer()
                    Text(lastUpdated?.formatted(Formatters.time) ?? "Never")
                        .monospacedDigit()
                }
                .font(.caption2)
                Button {
                    Task { await refreshAction() }
                } label: {
                    HStack {
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isRefreshing ? "Updating" : "Update Prices")
                        Spacer()
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 7)
                    .foregroundStyle(.white)
                    .background(WorthlineTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }
        }
    }
}
