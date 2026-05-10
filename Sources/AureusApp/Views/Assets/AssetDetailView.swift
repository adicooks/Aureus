import Charts
import SwiftData
import SwiftUI

enum AssetDetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case transactions = "Transactions"
    case chart = "Chart"
    case details = "Details"

    var id: String { rawValue }
}

struct AssetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var holding: Holding

    @State private var showingEdit = false
    @State private var showingTransactionEditor = false
    @State private var confirmDelete = false
    @State private var selectedTab: AssetDetailTab = .overview
    @State private var range: TimeRange = .oneYear

    private var visibleSnapshots: [PriceSnapshot] {
        let sorted = holding.priceSnapshots.sorted { $0.date < $1.date }
        let filtered = sorted.filter { range.contains($0.date) }
        return filtered.isEmpty ? sorted : filtered
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                tabs
                content
            }
            .padding(28)
        }
        .premiumPageBackground()
        .sheet(isPresented: $showingEdit) {
            AssetEditorView(holding: holding)
                .frame(minWidth: 560, minHeight: 620)
        }
        .sheet(isPresented: $showingTransactionEditor) {
            TransactionEditorView(preselectedHolding: holding)
                .frame(minWidth: 520, minHeight: 520)
        }
        .alert("Delete \(holding.name)?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                modelContext.delete(holding)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the asset, transactions, and local history.")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            AssetIcon(holding: holding)
                .scaleEffect(1.35)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(holding.name)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("\(holding.kind.singularTitle) · \(holding.displayTicker)")
                    .font(.callout)
                    .foregroundStyle(WorthlineTheme.textSecondary)
            }
            Spacer()
            SecondaryButton(title: "Edit", symbol: "pencil") { showingEdit = true }
            PrimaryButton(title: "Add Transaction", symbol: "plus") { showingTransactionEditor = true }
        }
    }

    private var tabs: some View {
        Picker("Detail Section", selection: $selectedTab) {
            ForEach(AssetDetailTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 420)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .overview:
            VStack(alignment: .leading, spacing: 18) {
                statGrid
                priceChart
                detailsGrid
            }
        case .transactions:
            assetTransactions
        case .chart:
            priceChart
        case .details:
            detailsGrid
        }
    }

    private var statGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 5), spacing: 14) {
            StatCard(title: "Current Price", value: currentPrice.formatted(Formatters.currency), symbol: "chart.line.uptrend.xyaxis", tint: WorthlineTheme.accent)
            StatCard(title: "Market Value", value: holding.currentValue.formatted(Formatters.currency), symbol: "dollarsign.circle", tint: .blue)
            StatCard(title: "Total Gain", value: holding.gainLoss.formatted(Formatters.currency), detail: holding.gainLossPercent.formatted(Formatters.percent), symbol: holding.gainLoss >= 0 ? "arrow.up.right.circle" : "arrow.down.right.circle", tint: holding.gainLoss >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
            StatCard(title: "Quantity", value: quantityText, symbol: "number", tint: .teal)
            StatCard(title: "Average Cost", value: holding.purchasePrice.formatted(Formatters.currency), symbol: "tag", tint: WorthlineTheme.warning)
        }
    }

    private var priceChart: some View {
        ChartCard(title: "Price History", trailing: {
            TimeRangePicker(selection: $range)
        }) {
            if visibleSnapshots.isEmpty {
                EmptyStateView(
                    title: "No price history yet",
                    message: "Refresh prices to cache local market data for this asset.",
                    symbol: "clock.arrow.circlepath"
                )
                .frame(height: 290)
            } else {
                Chart(visibleSnapshots) { snapshot in
                    AreaMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Price", snapshot.price)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.linearGradient(colors: [holding.kind.tint.opacity(0.20), holding.kind.tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    LineMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Price", snapshot.price)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(holding.kind.tint)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 300)
            }
        }
    }

    private var detailsGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "About")
                    detailRow("Type", holding.kind.singularTitle)
                    detailRow("Ticker", holding.displayTicker)
                    detailRow("Sector", holding.customCategory.isEmpty ? "Unspecified" : holding.customCategory)
                    detailRow("Industry", holding.kind.title)
                    detailRow("Dividend Yield", "Unavailable")
                    detailRow("Last Updated", holding.lastPriceUpdate?.formatted(Formatters.time) ?? "Manual")
                }
            }

            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Purchase Info")
                    detailRow("Purchase date", holding.purchaseDate.formatted(Formatters.shortDate))
                    detailRow("Quantity", quantityText)
                    detailRow("Purchase price", holding.purchasePrice.formatted(Formatters.currency))
                    detailRow("Fees", holding.fees.formatted(Formatters.currency))
                    if holding.kind == .bond {
                        detailRow("Principal", holding.principalAmount.formatted(Formatters.currency))
                        detailRow("Interest rate", "\(holding.interestRate.formatted(.number.precision(.fractionLength(0...3))))%")
                        if let maturityDate = holding.maturityDate {
                            detailRow("Maturity", maturityDate.formatted(Formatters.shortDate))
                        }
                    }
                }
            }

            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Notes")
                    Text(holding.notes.isEmpty ? "No notes." : holding.notes)
                        .font(.callout)
                        .foregroundStyle(holding.notes.isEmpty ? WorthlineTheme.textSecondary : WorthlineTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var assetTransactions: some View {
        SectionCard(padding: 0) {
            let transactions = holding.transactions.sorted { $0.date > $1.date }
            if transactions.isEmpty {
                EmptyStateView(
                    title: "No transactions yet",
                    message: "Add buys, sells, dividends, deposits, or withdrawals for this asset.",
                    symbol: "arrow.left.arrow.right",
                    buttonTitle: "Add Transaction",
                    action: { showingTransactionEditor = true }
                )
                .frame(minHeight: 420)
            } else {
                TransactionTable(transactions: transactions)
            }
        }
    }

    private var currentPrice: Double {
        if holding.kind.isMarketPriced {
            return holding.latestPrice ?? holding.purchasePrice
        }
        if holding.quantity > 0 {
            return holding.currentValue / holding.quantity
        }
        return holding.currentValue
    }

    private var quantityText: String {
        holding.kind == .bond ? holding.principalAmount.formatted(Formatters.currency) : holding.quantity.formatted(Formatters.number)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(WorthlineTheme.textSecondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}

