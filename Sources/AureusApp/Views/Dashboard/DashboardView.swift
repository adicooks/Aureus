import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \Holding.name) private var holdings: [Holding]
    @Query(sort: \NetWorthSnapshot.date) private var snapshots: [NetWorthSnapshot]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    let isRefreshing: Bool
    let refreshAction: () async -> Void
    let addAction: () -> Void

    @State private var range: TimeRange = .oneYear
    @State private var historySeries: [NetWorthHistoryPoint] = []
    @State private var chartNow = Date()
    @State private var refreshTask: Task<Void, Never>?

    private var summary: PortfolioSummary {
        PortfolioCalculator.summarize(holdings)
    }

    private var netWorthChartDomain: ClosedRange<Double> {
        let values = historySeries.map(\.totalValue).filter { $0.isFinite }
        guard let minimum = values.min(), let maximum = values.max(), maximum > 0 else {
            return 0...1
        }
        let spread = maximum - minimum
        let padding = max(spread * 0.18, maximum * 0.015, 1)
        return max(0, minimum - padding)...(maximum + padding)
    }

    private var netWorthChartXDomain: ClosedRange<Date>? {
        range.chartDomain(relativeTo: chartNow)
    }

    private var selectedRangeChange: (amount: Double, percent: Double) {
        guard let first = historySeries.first, let last = historySeries.last, first.totalValue > 0 else {
            return (
                summary.dailyChange ?? summary.unrealizedGainLoss,
                summary.dailyChangePercent ?? summary.unrealizedGainLossPercent
            )
        }
        let amount = last.totalValue - first.totalValue
        return (amount, amount / first.totalValue)
    }

    private var recentActivities: [DashboardActivity] {
        let transactionHoldingIDs = Set(transactions.compactMap { $0.holding?.id })
        let transactionActivities = transactions.map(DashboardActivity.transaction)
        let holdingActivities = holdings
            .filter { !$0.isArchived && !transactionHoldingIDs.contains($0.id) }
            .map(DashboardActivity.holding)
        return (transactionActivities + holdingActivities)
            .sorted { $0.date > $1.date }
    }

    private var holdingsVersion: String {
        holdings.map {
            [
                $0.id.uuidString,
                "\($0.quantity)",
                "\($0.purchasePrice)",
                "\($0.latestPrice ?? 0)",
                "\($0.previousClose ?? 0)",
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
                            title: "Start with your first asset",
                            message: "Add stocks, ETFs, bonds, cash, crypto, or custom holdings. Worthline keeps the portfolio local on this Mac.",
                            symbol: "chart.pie",
                            buttonTitle: "Add Asset",
                            action: addAction
                        )
                        .frame(minHeight: 430)
                    }
                } else {
                    dashboardHero
                    assetsAndTransactions
                }
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 34)
        }
        .premiumPageBackground()
        .onAppear(perform: scheduleChartRefresh)
        .onDisappear { refreshTask?.cancel() }
        .onChange(of: range) { _, _ in scheduleChartRefresh() }
        .onChange(of: holdingsVersion) { _, _ in scheduleChartRefresh() }
        .onChange(of: snapshotsVersion) { _, _ in scheduleChartRefresh() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Dashboard")
                    .font(.system(size: 34, weight: .regular, design: .rounded))
            }
            Spacer()
            SecondaryButton(title: isRefreshing ? "Refreshing" : "Refresh", symbol: "arrow.clockwise") {
                Task { await refreshAction() }
            }
            PrimaryButton(title: "Add Asset", symbol: "plus", action: addAction)
        }
    }

    private var dashboardHero: some View {
        SectionCard(padding: 0) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Total Net Worth")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(WorthlineTheme.textSecondary)
                            Text(summary.totalNetWorth, format: Formatters.currency)
                                .font(.system(size: 42, weight: .medium, design: .monospaced))
                                .monospacedDigit()
                        }
                        Spacer()
                        GainBadge(amount: selectedRangeChange.amount, percent: selectedRangeChange.percent)
                    }

                    TimeRangePicker(selection: $range)

                    if historySeries.isEmpty {
                        EmptyStateView(
                            title: "No chart data",
                            message: "Worthline will draw this timeline after the first snapshot is saved.",
                            symbol: "chart.xyaxis.line"
                        )
                        .frame(height: 230)
                    } else {
                        Chart(historySeries) { point in
                            AreaMark(
                                x: .value("Date", point.date),
                                yStart: .value("Baseline", netWorthChartDomain.lowerBound),
                                yEnd: .value("Net Worth", point.totalValue)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.linearGradient(colors: [WorthlineTheme.positive.opacity(0.24), WorthlineTheme.positive.opacity(0.02)], startPoint: .top, endPoint: .bottom))

                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Net Worth", point.totalValue)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(WorthlineTheme.positive)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Net Worth", point.totalValue)
                            )
                            .symbolSize(historySeries.count == 1 ? 42 : 10)
                            .foregroundStyle(WorthlineTheme.positive)
                        }
                        .chartYAxis {
                            AxisMarks(position: .trailing) { value in
                                AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                                AxisValueLabel {
                                    if let amount = value.as(Double.self) {
                                        Text(compactCurrency(amount))
                                            .font(.caption2)
                                            .foregroundStyle(WorthlineTheme.textSecondary)
                                    }
                                }
                            }
                        }
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) }
                        .chartYScale(domain: netWorthChartDomain)
                        .applyOptionalDateDomain(netWorthChartXDomain)
                        .chartPlotStyle { plot in
                            plot
                                .background(Color.white.opacity(0.015))
                        }
                        .animation(.smooth(duration: 0.25), value: range)
                        .frame(height: 250)
                        .clipped()
                    }
                }
                .padding(28)

                Divider()
                    .opacity(0.55)

                AllocationPanel(summary: summary)
                    .frame(width: 420)
                    .padding(.top, 28)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }
        }
    }

    private var assetsAndTransactions: some View {
        HStack(alignment: .top, spacing: 20) {
            DashboardAssetsCard(metrics: summary.metrics)
                .frame(maxWidth: .infinity)
                .frame(height: 430)
            DashboardTransactionsCard(activities: recentActivities)
                .frame(maxWidth: .infinity)
                .frame(height: 430)
        }
    }

    private func compactCurrency(_ amount: Double) -> String {
        let absolute = abs(amount)
        let prefix = amount < 0 ? "-" : ""
        if absolute >= 1_000_000 {
            return "\(prefix)$\((absolute / 1_000_000).formatted(.number.precision(.fractionLength(0...1))))M"
        }
        if absolute >= 1_000 {
            return "\(prefix)$\((absolute / 1_000).formatted(.number.precision(.fractionLength(0...0))))K"
        }
        return "\(prefix)$\(absolute.formatted(.number.precision(.fractionLength(0...0))))"
    }

    private func scheduleChartRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            guard !Task.isCancelled else { return }
            let now = Date()
            chartNow = now
            historySeries = PortfolioHistoryService.series(holdings: holdings, snapshots: snapshots, range: range, now: now)
        }
    }
}

private struct GainBadge: View {
    let amount: Double
    let percent: Double

    private var tint: Color {
        amount >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: amount >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text(amount, format: Formatters.currency)
            Text(percent, format: Formatters.percent)
        }
        .font(.caption.weight(.bold))
        .monospacedDigit()
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AllocationPanel: View {
    let summary: PortfolioSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Categories")
                .font(.headline.weight(.semibold))

            StackedAllocationBar(slices: summary.allocation)
                .frame(height: 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), alignment: .leading, spacing: 14) {
                ForEach(summary.allocation.prefix(6)) { slice in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(slice.kind.tint)
                                .frame(width: 8, height: 8)
                            Text(slice.kind.title)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                        Text(slice.percent, format: Formatters.percent)
                            .font(.callout)
                            .foregroundStyle(WorthlineTheme.textSecondary)
                            .monospacedDigit()
                    }
                }
            }

            Divider().opacity(0.5)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                MiniMetricBlock(title: "Net Worth", value: summary.totalNetWorth.formatted(Formatters.currency), tint: WorthlineTheme.accent)
                MiniMetricBlock(title: "Invested", value: summary.totalInvested.formatted(Formatters.currency), tint: .blue)
                MiniMetricBlock(title: "Gain/Loss", value: summary.unrealizedGainLoss.formatted(Formatters.currency), tint: summary.unrealizedGainLoss >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
                MiniMetricBlock(title: "Today", value: (summary.dailyChange ?? 0).formatted(Formatters.currency), tint: (summary.dailyChange ?? 0) >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
            }
        }
    }
}

private struct StackedAllocationBar: View {
    let slices: [AllocationSlice]

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 4) {
                ForEach(slices) { slice in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(slice.kind.tint)
                        .frame(width: max(10, proxy.size.width * slice.percent))
                }
            }
        }
    }
}

private struct MiniMetricBlock: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WorthlineTheme.textSecondary)
            Text(value)
                .font(.callout.weight(.bold))
                .foregroundStyle(WorthlineTheme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.8)
        }
    }
}

private struct DashboardAssetsCard: View {
    let metrics: [HoldingMetrics]

    var body: some View {
        SectionCard(padding: 26) {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(title: "Assets")
                if metrics.isEmpty {
                    Text("No movement yet")
                        .font(.callout)
                        .foregroundStyle(WorthlineTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Account")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Change")
                                .frame(width: 110, alignment: .center)
                            Text("Cost")
                                .frame(width: 125, alignment: .trailing)
                            Text("Value")
                                .frame(width: 125, alignment: .trailing)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WorthlineTheme.textSecondary)
                        .textCase(.uppercase)
                        .padding(.bottom, 14)

                        ForEach(metrics.prefix(6)) { metric in
                            DashboardAssetRow(metric: metric)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct DashboardAssetRow: View {
    let metric: HoldingMetrics

    var body: some View {
        HStack(spacing: 14) {
            AssetIcon(holding: metric.holding)
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.holding.displayTicker)
                    .font(.callout.weight(.semibold))
                Text(metric.holding.name)
                    .font(.caption)
                    .foregroundStyle(WorthlineTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(metric.gainLossPercent, format: Formatters.percent)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(metric.gainLoss >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background((metric.gainLoss >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(width: 110, alignment: .center)

            Text(metric.costBasis, format: Formatters.currency)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(width: 125, alignment: .trailing)
            Text(metric.currentValue, format: Formatters.currency)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(width: 125, alignment: .trailing)
        }
        .padding(.vertical, 12)
    }
}

private enum DashboardActivity: Identifiable {
    case transaction(Transaction)
    case holding(Holding)

    var id: String {
        switch self {
        case .transaction(let transaction): "transaction-\(transaction.id.uuidString)"
        case .holding(let holding): "holding-\(holding.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .transaction(let transaction): transaction.date
        case .holding(let holding): holding.purchaseDate
        }
    }
}

private struct DashboardTransactionsCard: View {
    let activities: [DashboardActivity]

    var body: some View {
        SectionCard(padding: 26) {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(title: "Transactions")
                if activities.isEmpty {
                    Text("No transactions yet")
                        .font(.callout)
                        .foregroundStyle(WorthlineTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(activities) { activity in
                                DashboardTransactionRow(activity: activity)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

private extension View {
    @ViewBuilder
    func applyOptionalDateDomain(_ domain: ClosedRange<Date>?) -> some View {
        if let domain {
            self.chartXScale(domain: domain)
        } else {
            self
        }
    }
}

private struct DashboardTransactionRow: View {
    let activity: DashboardActivity

    private var tint: Color {
        isPositiveActivity ? WorthlineTheme.positive : WorthlineTheme.negative
    }

    private var amount: Double {
        switch activity {
        case .transaction(let transaction): transaction.signedAmount
        case .holding(let holding): holding.costBasis
        }
    }

    private var displayAmount: Double {
        isPositiveActivity ? abs(amount) : -abs(amount)
    }

    private var isPositiveActivity: Bool {
        switch activity {
        case .transaction(let transaction):
            return transaction.presentationIsPositive
        case .holding:
            return true
        }
    }

    private var symbol: String {
        switch activity {
        case .transaction(let transaction): transaction.kind.symbol
        case .holding: TransactionKind.buy.symbol
        }
    }

    private var holding: Holding? {
        switch activity {
        case .transaction(let transaction): transaction.holding
        case .holding(let holding): holding
        }
    }

    private var title: String {
        switch activity {
        case .transaction(let transaction): transaction.kind.title
        case .holding: TransactionKind.buy.title
        }
    }

    private var subtitle: String {
        switch activity {
        case .transaction(let transaction):
            return transaction.note.isEmpty ? (transaction.holding?.name ?? transaction.holding?.displayTicker ?? "Unassigned") : transaction.note
        case .holding(let holding):
            return "\(holding.displayTicker) · \(holding.name)"
        }
    }

    private var date: Date {
        activity.date
    }

    var body: some View {
        HStack(spacing: 12) {
            if let holding {
                AssetIcon(holding: holding)
                    .frame(width: 42, height: 42)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.14))
                    Image(systemName: symbol)
                        .foregroundStyle(tint)
                }
                .frame(width: 42, height: 42)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayAmount, format: Formatters.currency)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                Text("\(title) · \(subtitle)")
                    .font(.caption)
                    .foregroundStyle(WorthlineTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(date.formatted(Formatters.compactDate))
                Text(date.formatted(Formatters.time))
            }
            .font(.caption)
            .foregroundStyle(WorthlineTheme.textSecondary)
            .monospacedDigit()
        }
    }
}
