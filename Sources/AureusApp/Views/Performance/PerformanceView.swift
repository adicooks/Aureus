import Charts
import SwiftData
import SwiftUI

struct PerformanceView: View {
    @Query(sort: \Holding.name) private var holdings: [Holding]
    @Query(sort: \NetWorthSnapshot.date) private var snapshots: [NetWorthSnapshot]

    let snapshotAction: () -> Void

    @State private var range: TimeRange = .oneYear
    @State private var historySeries: [NetWorthHistoryPoint] = []
    @State private var summary = PortfolioCalculator.summarize([])
    @State private var isPreparing = true
    @State private var refreshTask: Task<Void, Never>?

    private var returnSeries: [(date: Date, returnValue: Double)] {
        guard let first = historySeries.first, first.totalValue > 0 else { return [] }
        return historySeries.map { ($0.date, ($0.totalValue - first.totalValue) / first.totalValue) }
    }

    private var timeWeightedReturn: Double {
        guard let first = historySeries.first, let last = historySeries.last, first.totalValue > 0 else { return summary.unrealizedGainLossPercent }
        return (last.totalValue - first.totalValue) / first.totalValue
    }

    private var moneyWeightedReturn: Double {
        summary.totalInvested > 0 ? summary.unrealizedGainLoss / summary.totalInvested : 0
    }

    private var dailyReturns: [Double] {
        guard historySeries.count > 1 else { return [] }
        return zip(historySeries.dropFirst(), historySeries).compactMap { current, previous in
            previous.totalValue > 0 ? (current.totalValue - previous.totalValue) / previous.totalValue : nil
        }
    }

    private var holdingsVersion: String {
        holdings.map {
            [
                $0.id.uuidString,
                "\($0.quantity)",
                "\($0.purchasePrice)",
                "\($0.latestPrice ?? 0)",
                "\($0.updatedAt.timeIntervalSince1970)",
                "\($0.priceSnapshots.count)"
            ].joined(separator: ":")
        }
        .joined(separator: "|")
    }

    private var snapshotsVersion: String {
        snapshots.map { "\($0.id.uuidString):\($0.date.timeIntervalSince1970):\($0.totalValue)" }
            .joined(separator: "|")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if holdings.isEmpty {
                    SectionCard {
                        EmptyStateView(
                            title: "Performance appears after assets",
                            message: "Worthline will chart returns, allocation, and profit/loss once the portfolio has data.",
                            symbol: "chart.xyaxis.line"
                        )
                        .frame(minHeight: 430)
                    }
                } else if isPreparing {
                    SectionCard {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 430)
                    }
                } else {
                    stats
                    HStack(alignment: .top, spacing: 16) {
                        performanceChart
                        assetClassPerformance
                    }
                    profitLossChart
                }
            }
            .padding(28)
        }
        .premiumPageBackground()
        .onAppear(perform: scheduleRefresh)
        .onDisappear { refreshTask?.cancel() }
        .onChange(of: range) { _, _ in scheduleRefresh() }
        .onChange(of: holdingsVersion) { _, _ in scheduleRefresh() }
        .onChange(of: snapshotsVersion) { _, _ in scheduleRefresh() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Performance")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("Returns, snapshots, and asset-class contribution.")
                    .font(.callout)
                    .foregroundStyle(WorthlineTheme.textSecondary)
            }
            Spacer()
            TimeRangePicker(selection: $range)
            PrimaryButton(title: "Save Snapshot", symbol: "camera") {
                snapshotAction()
            }
        }
    }

    private var stats: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
            StatCard(
                title: "Time Weighted Return",
                value: timeWeightedReturn.formatted(Formatters.percent),
                symbol: "function",
                tint: timeWeightedReturn >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative,
                help: "Shows portfolio return over the selected period while reducing the effect of added or removed money."
            )
            StatCard(
                title: "Money Weighted Return",
                value: moneyWeightedReturn.formatted(Formatters.percent),
                symbol: "sum",
                tint: moneyWeightedReturn >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative,
                help: "Compares current gain or loss with the dollars you invested, so your cash timing affects the result."
            )
            StatCard(title: "Best Day", value: (dailyReturns.max() ?? 0).formatted(Formatters.percent), symbol: "arrow.up.right", tint: WorthlineTheme.positive)
            StatCard(title: "Worst Day", value: (dailyReturns.min() ?? 0).formatted(Formatters.percent), symbol: "arrow.down.right", tint: WorthlineTheme.negative)
        }
    }

    private var performanceChart: some View {
        ChartCard(title: "Performance Overview") {
            if returnSeries.isEmpty {
                EmptyStateView(
                    title: "No return chart yet",
                    message: "Save snapshots over time to build a return curve.",
                    symbol: "chart.line.uptrend.xyaxis"
                )
                .frame(height: 330)
            } else {
                Chart(returnSeries, id: \.date) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Return", point.returnValue)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.linearGradient(colors: [WorthlineTheme.positive.opacity(0.22), WorthlineTheme.positive.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Return", point.returnValue)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(WorthlineTheme.positive)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 330)
            }
        }
    }

    private var assetClassPerformance: some View {
        ChartCard(title: "Performance by Asset Class") {
            VStack(spacing: 14) {
                ForEach(summary.allocation) { slice in
                    let classMetrics = summary.metrics.filter { $0.holding.kind == slice.kind }
                    let gain = classMetrics.reduce(0) { $0 + $1.gainLoss }
                    let basis = classMetrics.reduce(0) { $0 + $1.costBasis }
                    let percent = basis > 0 ? gain / basis : 0
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(slice.kind.title)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(percent, format: Formatters.percent)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(percent >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
                                .monospacedDigit()
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.12))
                                Capsule()
                                    .fill(percent >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
                                    .frame(width: max(8, proxy.size.width * min(abs(percent), 1)))
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .frame(minHeight: 330, alignment: .top)
        }
        .frame(width: 330)
    }

    private var profitLossChart: some View {
        ChartCard(title: "Profit and Loss by Holding") {
            Chart(summary.metrics) { metric in
                BarMark(
                    x: .value("Gain/Loss", metric.gainLoss),
                    y: .value("Holding", metric.holding.name)
                )
                .foregroundStyle(metric.gainLoss >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
                .cornerRadius(5)
            }
            .chartXAxis { AxisMarks(position: .bottom) }
            .frame(height: max(260, CGFloat(summary.metrics.count) * 34))
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        isPreparing = true
        refreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled else { return }
            summary = PortfolioCalculator.summarize(holdings)
            historySeries = PortfolioHistoryService.series(holdings: holdings, snapshots: snapshots, range: range)
            isPreparing = false
        }
    }
}
