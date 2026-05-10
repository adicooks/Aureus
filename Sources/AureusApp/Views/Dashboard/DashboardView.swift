import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \Holding.name) private var holdings: [Holding]
    @Query(sort: \NetWorthSnapshot.date) private var snapshots: [NetWorthSnapshot]

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
                    metricGrid
                    chartAndAllocation
                    bottomCards
                }
            }
            .padding(28)
        }
        .premiumPageBackground()
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Dashboard")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("A clean read on your local net worth.")
                    .font(.callout)
                    .foregroundStyle(WorthlineTheme.textSecondary)
            }
            Spacer()
            SecondaryButton(title: isRefreshing ? "Refreshing" : "Refresh", symbol: "arrow.clockwise") {
                Task { await refreshAction() }
            }
            PrimaryButton(title: "Add Asset", symbol: "plus", action: addAction)
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

    private var chartAndAllocation: some View {
        HStack(alignment: .top, spacing: 16) {
            ChartCard(title: "Net Worth Over Time", trailing: {
                TimeRangePicker(selection: $range)
            }) {
                if historySeries.isEmpty {
                    EmptyStateView(
                        title: "No chart data",
                        message: "Worthline will draw this timeline after the first snapshot is saved.",
                        symbol: "chart.xyaxis.line"
                    )
                    .frame(height: 310)
                } else {
                    Chart(historySeries) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Net Worth", point.totalValue)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.linearGradient(colors: [WorthlineTheme.accent.opacity(0.22), WorthlineTheme.accent.opacity(0.015)], startPoint: .top, endPoint: .bottom))
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Net Worth", point.totalValue)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(WorthlineTheme.accent)
                    }
                    .chartYAxis { AxisMarks(position: .leading) }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
                    .animation(.smooth(duration: 0.25), value: range)
                    .frame(height: 310)
                }
            }

            ChartCard(title: "Asset Allocation") {
                VStack(spacing: 16) {
                    AllocationDonutChart(slices: summary.allocation)
                        .frame(height: 210)

                    VStack(spacing: 9) {
                        ForEach(summary.allocation) { slice in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(slice.kind.tint)
                                    .frame(width: 8, height: 8)
                                Text(slice.kind.title)
                                    .font(.callout)
                                Spacer()
                                Text(slice.percent, format: Formatters.percent)
                                    .font(.callout.weight(.semibold))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .frame(width: 330)
        }
    }

    private var bottomCards: some View {
        HStack(alignment: .top, spacing: 16) {
            MoversCard(title: "Top Gainers", metrics: summary.topGainers)
            MoversCard(title: "Top Losers", metrics: summary.topLosers)
            AssetBreakdownCard(allocation: summary.allocation)
        }
    }
}

private struct MoversCard: View {
    let title: String
    let metrics: [HoldingMetrics]

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: title)
                if metrics.isEmpty {
                    Text("No movement yet")
                        .font(.callout)
                        .foregroundStyle(WorthlineTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 24)
                } else {
                    ForEach(metrics) { metric in
                        AssetRow(metric: metric)
                    }
                }
            }
        }
    }
}

private struct AssetBreakdownCard: View {
    let allocation: [AllocationSlice]

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 13) {
                SectionHeader(title: "Asset Breakdown")
                ForEach(allocation) { slice in
                    VStack(spacing: 6) {
                        HStack {
                            Label(slice.kind.title, systemImage: slice.kind.symbol)
                                .foregroundStyle(slice.kind.tint)
                            Spacer()
                            Text(slice.value, format: Formatters.currency)
                                .monospacedDigit()
                                .font(.callout.weight(.semibold))
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.12))
                                Capsule()
                                    .fill(slice.kind.tint)
                                    .frame(width: max(6, proxy.size.width * slice.percent))
                            }
                        }
                        .frame(height: 7)
                    }
                    .font(.callout)
                }
            }
        }
    }
}
