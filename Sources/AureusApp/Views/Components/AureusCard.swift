import Charts
import AppKit
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
        guard let start = startDate(relativeTo: now) else {
            return true
        }
        return date >= start
    }

    func startDate(relativeTo now: Date = .now, calendar: Calendar = .current) -> Date? {
        let startOfToday = calendar.startOfDay(for: now)
        switch self {
        case .oneDay:
            return startOfToday
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: startOfToday)
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: startOfToday)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: startOfToday)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: startOfToday)
        case .all:
            return nil
        }
    }

    func chartDomain(relativeTo now: Date = .now, calendar: Calendar = .current) -> ClosedRange<Date>? {
        guard let start = startDate(relativeTo: now, calendar: calendar) else { return nil }
        let end = now
        return start...max(end, start.addingTimeInterval(60))
    }
}

struct SectionCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(WorthlineTheme.cardBackground)
                    .overlay {
                        LinearGradient(
                            colors: [Color.white.opacity(0.070), Color.white.opacity(0.018), Color.black.opacity(0.16)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            .blur(radius: 0.2)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(WorthlineTheme.border, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.34), radius: 22, x: 0, y: 14)
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
                    .background(matteControlBackground)
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
    var help: String?

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
                    HStack(spacing: 5) {
                        Text(title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(WorthlineTheme.textSecondary)
                        if let help {
                            InfoHoverButton(help: help)
                        }
                    }
                    Text(value)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(detail ?? " ")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(detail == nil ? Color.clear : tint)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .frame(minHeight: 92, alignment: .top)
        }
    }
}

private struct InfoHoverButton: View {
    let help: String
    @State private var isHovering = false

    var body: some View {
        Image(systemName: "info.circle")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(WorthlineTheme.textSecondary)
            .padding(3)
            .contentShape(Rectangle())
            .help(help)
            .onHover { isHovering = $0 }
            .overlay(alignment: .bottomLeading) {
                if isHovering {
                    Text(help)
                        .font(.caption)
                        .foregroundStyle(WorthlineTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 238, alignment: .leading)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(WorthlineTheme.border, lineWidth: 0.8)
                        }
                        .shadow(color: .black.opacity(0.24), radius: 14, y: 8)
                        .offset(x: -8, y: 36)
                        .zIndex(20)
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
                        .aureusPillBackground(isSelected: selection == range)
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
                        .aureusPillBackground(isSelected: selection == option)
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
        .background(matteFieldBackground)
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
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary)
                .overlay {
                    LinearGradient(colors: [Color.white.opacity(0.24), Color.clear], startPoint: .top, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
        }
        .shadow(color: .black.opacity(0.30), radius: 12, y: 6)
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
        .background(matteControlBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(WorthlineTheme.border, lineWidth: 0.8)
        }
    }
}

private var matteControlBackground: some View {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.white.opacity(0.055))
        .overlay {
            LinearGradient(colors: [Color.white.opacity(0.075), Color.clear], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
}

private var matteFieldBackground: some View {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(WorthlineTheme.fieldBackground)
        .overlay {
            LinearGradient(colors: [Color.white.opacity(0.055), Color.clear], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
}

private extension View {
    func aureusPillBackground(isSelected: Bool) -> some View {
        background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.145) : Color.white.opacity(0.055))
                .overlay {
                    LinearGradient(
                        colors: [Color.white.opacity(isSelected ? 0.16 : 0.075), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
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
        .lineLimit(1)
        .minimumScaleFactor(0.72)
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

    private var logoURLString: String? {
        guard let logoURL = holding.logoURL, URL(string: logoURL) != nil else { return nil }
        return logoURL
    }

    var body: some View {
        LogoTile(
            logoURLString: logoURLString,
            fallbackText: initials,
            fallbackTint: fallbackTint,
            systemSymbol: systemSymbol,
            size: 34
        )
    }

    private var initials: String {
        if isGoldCommodity {
            return "AU"
        }
        let source = holding.ticker.isEmpty ? holding.name : holding.ticker
        return String(source.prefix(2)).uppercased()
    }

    private var usesDefaultAssetSymbol: Bool {
        holding.kind == .cash || holding.kind == .realEstate || holding.kind == .bond || holding.kind == .commodity
    }

    private var isGoldCommodity: Bool {
        holding.ticker.uppercased() == "GC=F" || holding.name.caseInsensitiveCompare("Gold") == .orderedSame
    }

    private var fallbackTint: Color {
        isGoldCommodity ? Color(red: 0.95, green: 0.66, blue: 0.18) : holding.kind.tint
    }

    private var systemSymbol: String? {
        usesDefaultAssetSymbol ? holding.kind.symbol : nil
    }
}

struct LogoTile: View {
    let logoURLString: String?
    let fallbackText: String
    let fallbackTint: Color
    var systemSymbol: String?
    var size: CGFloat = 34

    @State private var sampledPalette: LogoPalette?

    private var tileFill: Color {
        if let sampledPalette {
            return sampledPalette.color.opacity(sampledPalette.isLight ? 0.18 : 0.22)
        }
        return fallbackTint.opacity(0.14)
    }

    private var tileStroke: Color {
        if let sampledPalette {
            return sampledPalette.color.opacity(sampledPalette.isLight ? 0.70 : 0.52)
        }
        return fallbackTint.opacity(0.28)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tileFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tileStroke, lineWidth: 0.9)
                }

            if let logoURLString, let url = URL(string: logoURLString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(5)
                    default:
                        fallbackView
                    }
                }
            } else if let systemSymbol {
                Image(systemName: systemSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(fallbackTint)
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .id(logoURLString ?? fallbackText)
        .task(id: logoURLString) {
            await sampleLogoPalette(from: logoURLString)
        }
    }

    private var fallbackView: some View {
        Text(String(fallbackText.prefix(2)).uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(fallbackTint)
    }

    private func sampleLogoPalette(from logoURLString: String?) async {
        await MainActor.run {
            sampledPalette = nil
        }
        guard let logoURLString, let url = URL(string: logoURLString) else { return }
        if let cached = await MainActor.run(body: { LogoPaletteCache.shared.palette(for: logoURLString) }) {
            await MainActor.run {
                sampledPalette = cached
            }
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let palette = await Task.detached(priority: .utility, operation: {
                LogoPalette(data: data)
            }).value else { return }
            await MainActor.run {
                LogoPaletteCache.shared.set(palette, for: logoURLString)
                sampledPalette = palette
            }
        } catch {
            await MainActor.run {
                sampledPalette = nil
            }
        }
    }
}

private struct LogoPalette: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var isLight: Bool {
        (0.299 * red + 0.587 * green + 0.114 * blue) > 0.72
    }

    init?(data: Data) {
        guard let image = NSImage(data: data),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard width > 0, height > 0 else { return nil }

        let edgeColor = Self.averageColor(in: bitmap, width: width, height: height, edgesOnly: true)
        let fallbackColor = Self.averageColor(in: bitmap, width: width, height: height, edgesOnly: false)
        guard let color = edgeColor ?? fallbackColor else { return nil }
        red = color.red
        green = color.green
        blue = color.blue
    }

    private static func averageColor(
        in bitmap: NSBitmapImageRep,
        width: Int,
        height: Int,
        edgesOnly: Bool
    ) -> (red: Double, green: Double, blue: Double)? {
        let maxSamplesPerAxis = 28
        let xStride = max(1, width / maxSamplesPerAxis)
        let yStride = max(1, height / maxSamplesPerAxis)
        let edgeBand = max(1, min(width, height) / 8)
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var weightTotal = 0.0

        for y in stride(from: 0, to: height, by: yStride) {
            for x in stride(from: 0, to: width, by: xStride) {
                if edgesOnly {
                    let isEdge = x < edgeBand || x >= width - edgeBand || y < edgeBand || y >= height - edgeBand
                    guard isEdge else { continue }
                }
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let alpha = color.alphaComponent
                let compositedRed = color.redComponent * alpha + (1 - alpha)
                let compositedGreen = color.greenComponent * alpha + (1 - alpha)
                let compositedBlue = color.blueComponent * alpha + (1 - alpha)
                red += compositedRed
                green += compositedGreen
                blue += compositedBlue
                weightTotal += 1
            }
        }

        guard weightTotal > 0 else { return nil }
        return (red / weightTotal, green / weightTotal, blue / weightTotal)
    }
}

private final class LogoPaletteCache {
    static let shared = LogoPaletteCache()
    private var values: [String: LogoPalette] = [:]

    private init() {}

    func palette(for key: String) -> LogoPalette? {
        values[key]
    }

    func set(_ palette: LogoPalette, for key: String) {
        values[key] = palette
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
        .contextMenu {
            if let action {
                Button("Open", systemImage: "arrow.up.right.square", action: action)
            }
        }
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
