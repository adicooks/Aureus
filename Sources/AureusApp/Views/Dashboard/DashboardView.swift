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

    private var summary: PortfolioSummary {
        PortfolioCalculator.summarize(holdings)
    }

    private var historySeries: [NetWorthHistoryPoint] {
        PortfolioHistoryService.series(holdings: holdings, snapshots: snapshots, range: range)
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
                    metricGrid
                    assetsAndTransactions
                }
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 34)
        }
        .premiumPageBackground()
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
            HStack(spacing: 0) {
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
                        GainBadge(amount: summary.dailyChange ?? summary.unrealizedGainLoss, percent: summary.dailyChangePercent ?? summary.unrealizedGainLossPercent)
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
                            BarMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Net Worth", point.totalValue)
                            )
                            .foregroundStyle(WorthlineTheme.positive)
                            .cornerRadius(4)
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
                        .chartPlotStyle { plot in
                            plot
                                .background(Color.white.opacity(0.015))
                        }
                        .animation(.smooth(duration: 0.25), value: range)
                        .frame(height: 250)
                    }
                }
                .padding(28)

                Divider()
                    .opacity(0.55)

                AllocationPanel(summary: summary)
                    .frame(width: 360)
                    .padding(28)
            }
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
            StatCard(
                title: "Net Worth",
                value: summary.totalNetWorth.formatted(Formatters.currency),
                detail: "\(holdings.count) holdings",
                symbol: "dollarsign.circle",
                tint: WorthlineTheme.accent
            )
            StatCard(
                title: "Total Invested",
                value: summary.totalInvested.formatted(Formatters.currency),
                detail: "Cost basis",
                symbol: "tray.and.arrow.down",
                tint: .blue
            )
            StatCard(
                title: "Total Gain/Loss",
                value: summary.unrealizedGainLoss.formatted(Formatters.currency),
                detail: summary.unrealizedGainLossPercent.formatted(Formatters.percent),
                symbol: summary.unrealizedGainLoss >= 0 ? "arrow.up.right.circle" : "arrow.down.right.circle",
                tint: summary.unrealizedGainLoss >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative
            )
            StatCard(
                title: "Today's Change",
                value: (summary.dailyChange ?? 0).formatted(Formatters.currency),
                detail: summary.dailyChangePercent?.formatted(Formatters.percent) ?? "Awaiting prices",
                symbol: "waveform.path.ecg",
                tint: (summary.dailyChange ?? 0) >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative
            )
        }
    }

    private var assetsAndTransactions: some View {
        HStack(alignment: .top, spacing: 20) {
            DashboardAssetsCard(metrics: summary.metrics)
            DashboardTransactionsCard(transactions: Array(transactions.prefix(6)))
                .frame(width: 410)
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

    private var score: Int {
        min(99, max(0, summary.allocation.count * 14 + Int((1 - concentration) * 35)))
    }

    private var concentration: Double {
        summary.allocation.map(\.percent).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Categories")
                .font(.headline.weight(.semibold))

            StackedAllocationBar(slices: summary.allocation)
                .frame(height: 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 2), alignment: .leading, spacing: 18) {
                ForEach(summary.allocation.prefix(6)) { slice in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(slice.kind.tint)
                                .frame(width: 8, height: 8)
                            Text(slice.kind.title)
                                .font(.callout.weight(.medium))
                        }
                        Text(slice.percent, format: Formatters.percent)
                            .font(.callout)
                            .foregroundStyle(WorthlineTheme.textSecondary)
                            .monospacedDigit()
                    }
                }
            }

            Divider().opacity(0.5)

            HStack {
                Text("Diversification Score")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(score)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(WorthlineTheme.positive)
                    .monospacedDigit()
            }
            ScoreBars(score: score)

            Text("\(summary.metrics.count) holdings across \(summary.allocation.count) categories")
                .font(.callout.weight(.medium))
                .foregroundStyle(WorthlineTheme.textPrimary)
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

private struct ScoreBars: View {
    let score: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<14, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(index < Int(Double(score) / 100 * 14) ? WorthlineTheme.positive : Color.secondary.opacity(0.22))
                    .frame(height: 10)
            }
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
                                .frame(width: 110, alignment: .trailing)
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
                    }
                }
            }
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
                .frame(width: 110, alignment: .trailing)

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

private struct DashboardTransactionsCard: View {
    let transactions: [Transaction]

    var body: some View {
        SectionCard(padding: 26) {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(title: "Transactions")
                if transactions.isEmpty {
                    Text("No transactions yet")
                        .font(.callout)
                        .foregroundStyle(WorthlineTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
                } else {
                    VStack(spacing: 14) {
                        ForEach(transactions) { transaction in
                            DashboardTransactionRow(transaction: transaction)
                        }
                    }
                }
            }
        }
    }
}

private struct DashboardTransactionRow: View {
    let transaction: Transaction

    private var tint: Color {
        transaction.signedAmount >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: transaction.kind.symbol)
                    .foregroundStyle(tint)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.signedAmount, format: Formatters.currency)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                Text(transaction.note.isEmpty ? (transaction.holding?.name ?? transaction.kind.title) : transaction.note)
                    .font(.caption)
                    .foregroundStyle(WorthlineTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.date.formatted(Formatters.compactDate))
                Text(transaction.date.formatted(Formatters.time))
            }
            .font(.caption)
            .foregroundStyle(WorthlineTheme.textSecondary)
            .monospacedDigit()
        }
    }
}
