import Charts
import SwiftData
import SwiftUI

struct ReportsView: View {
    @Query(sort: \Holding.name) private var holdings: [Holding]
    @Query(sort: \NetWorthSnapshot.date) private var snapshots: [NetWorthSnapshot]

    private var summary: PortfolioSummary {
        PortfolioCalculator.summarize(holdings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if holdings.isEmpty {
                    SectionCard {
                        EmptyStateView(
                            title: "Reports need portfolio data",
                            message: "Add holdings to generate allocation, return, and concentration reports.",
                            symbol: "doc.text.magnifyingglass"
                        )
                        .frame(minHeight: 470)
                    }
                } else {
                    statGrid
                    HStack(alignment: .top, spacing: 16) {
                        allocationReport
                        concentrationReport
                    }
                    snapshotReport
                }
            }
            .padding(28)
        }
        .premiumPageBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Reports")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Portfolio composition, concentration, and saved net-worth records.")
                .font(.callout)
                .foregroundStyle(WorthlineTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
            StatCard(title: "Assets", value: "\(summary.metrics.count)", symbol: "square.stack.3d.up", tint: WorthlineTheme.accent)
            StatCard(title: "Categories", value: "\(summary.allocation.count)", symbol: "chart.pie", tint: .teal)
            StatCard(title: "Largest Position", value: (summary.metrics.first?.allocation ?? 0).formatted(Formatters.percent), symbol: "scope", tint: WorthlineTheme.warning)
            StatCard(title: "Snapshots", value: "\(snapshots.count)", symbol: "camera", tint: .blue)
        }
    }

    private var allocationReport: some View {
        ChartCard(title: "Allocation Report") {
            Chart(summary.allocation) { slice in
                BarMark(
                    x: .value("Value", slice.value),
                    y: .value("Category", slice.kind.title)
                )
                .foregroundStyle(slice.kind.tint)
                .cornerRadius(5)
                .annotation(position: .trailing) {
                    Text(slice.percent, format: Formatters.percent)
                        .font(.caption)
                        .foregroundStyle(WorthlineTheme.textSecondary)
                }
            }
            .frame(height: 320)
        }
    }

    private var concentrationReport: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Largest Holdings")
                ForEach(summary.metrics.prefix(8)) { metric in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(metric.holding.name)
                                .font(.callout.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            Text(metric.allocation, format: Formatters.percent)
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.12))
                                Capsule()
                                    .fill(metric.holding.kind.tint)
                                    .frame(width: max(8, proxy.size.width * metric.allocation))
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .frame(minHeight: 320, alignment: .top)
        }
        .frame(width: 350)
    }

    private var snapshotReport: some View {
        SectionCard(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Snapshot History")
                        .font(.headline.weight(.semibold))
                    Spacer()
                }
                .padding(18)
                .overlay(alignment: .bottom) { Divider() }

                if snapshots.isEmpty {
                    EmptyStateView(
                        title: "No snapshots saved",
                        message: "Snapshots appear here after daily or manual saves.",
                        symbol: "camera"
                    )
                    .frame(height: 280)
                } else {
                    ForEach(snapshots.suffix(10).reversed()) { snapshot in
                        HStack {
                            Text(snapshot.date.formatted(Formatters.shortDate))
                                .frame(width: 140, alignment: .leading)
                            Text(snapshot.note.isEmpty ? "Snapshot" : snapshot.note)
                                .foregroundStyle(WorthlineTheme.textSecondary)
                            Spacer()
                            Text(snapshot.totalValue, format: Formatters.currency)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                            Text(snapshot.unrealizedGainLoss, format: Formatters.currency)
                                .foregroundStyle(snapshot.unrealizedGainLoss >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
                                .monospacedDigit()
                                .frame(width: 130, alignment: .trailing)
                        }
                        .font(.callout)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        Divider().opacity(0.55)
                    }
                }
            }
        }
    }
}

