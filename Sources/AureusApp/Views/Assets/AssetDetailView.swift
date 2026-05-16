import Charts
import SwiftData
import SwiftUI

enum AssetDetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case transactions = "Transactions"
    case chart = "Chart"
    case details = "Details"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .transactions: "arrow.left.arrow.right"
        case .chart: "chart.line.uptrend.xyaxis"
        case .details: "list.bullet.rectangle"
        }
    }
}

private struct AssetPricePoint: Identifiable {
    var id: Date { date }
    let date: Date
    let price: Double
}

struct AssetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var holding: Holding
    var closeAction: (() -> Void)?

    @State private var showingEdit = false
    @State private var showingTransactionEditor = false
    @State private var confirmDelete = false
    @State private var selectedTab: AssetDetailTab = .overview
    @State private var range: TimeRange = .oneYear
    @State private var selectedPricePoint: AssetPricePoint?

    private var visiblePricePoints: [AssetPricePoint] {
        pricePoints.filter { range.contains($0.date) }
    }

    private var pricePoints: [AssetPricePoint] {
        var points = holding.priceSnapshots.map { AssetPricePoint(date: $0.date, price: $0.price) }
        if holding.kind.isMarketPriced, holding.purchasePrice > 0 {
            points.append(AssetPricePoint(date: holding.purchaseDate, price: holding.purchasePrice))
        }
        if holding.kind.isMarketPriced, currentPrice > 0 {
            points.append(AssetPricePoint(date: holding.lastPriceUpdate ?? .now, price: currentPrice))
        }
        return points
            .sorted { $0.date < $1.date }
            .reduce(into: [AssetPricePoint]()) { result, point in
                if let lastIndex = result.indices.last, Calendar.current.isDate(result[lastIndex].date, inSameDayAs: point.date) {
                    result[lastIndex] = point
                } else {
                    result.append(point)
                }
            }
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
                close()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the asset, transactions, and local history.")
        }
        .onChange(of: range) { _, _ in
            selectedPricePoint = nil
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                close()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            DetailHeaderButton(title: "Edit", symbol: "pencil") {
                showingEdit = true
            }
            DetailHeaderButton(title: "Transaction", symbol: "plus", isProminent: true) {
                showingTransactionEditor = true
            }
        }
    }

    private var tabs: some View {
        DetailTabBar(selection: $selectedTab)
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
            if visiblePricePoints.isEmpty {
                EmptyStateView(
                    title: "No price history yet",
                    message: "Refresh prices to cache local market data for this asset.",
                    symbol: "clock.arrow.circlepath"
                )
                .frame(height: 290)
            } else {
                Chart(visiblePricePoints) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Price", point.price)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.linearGradient(colors: [holding.kind.tint.opacity(0.20), holding.kind.tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Price", point.price)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(holding.kind.tint)

                    if let selectedPricePoint, selectedPricePoint.id == point.id {
                        RuleMark(x: .value("Selected Date", selectedPricePoint.date))
                            .foregroundStyle(Color.white.opacity(0.22))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        PointMark(
                            x: .value("Selected Date", selectedPricePoint.date),
                            y: .value("Selected Price", selectedPricePoint.price)
                        )
                        .symbolSize(84)
                        .foregroundStyle(holding.kind.tint)
                        .annotation(position: .top, alignment: .center, spacing: 8) {
                            ChartTraceLabel(
                                title: selectedPricePoint.price.formatted(Formatters.currency),
                                subtitle: selectedPricePoint.date.formatted(Formatters.compactDate),
                                tint: holding.kind.tint
                            )
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(priceChartTraceGesture(proxy: proxy, geometry: geometry))
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    updateSelectedPricePoint(at: location, proxy: proxy, geometry: geometry)
                                case .ended:
                                    selectedPricePoint = nil
                                }
                            }
                    }
                }
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
                    detailRow("Sector", holding.sector ?? fallbackCategory)
                    detailRow("Industry", holding.industry ?? holding.kind.title)
                    detailRow("Dividend Yield", holding.dividendYield?.formatted(Formatters.percent) ?? "Unavailable")
                    detailRow("Earnings Date", holding.earningsDate ?? "Unavailable")
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
                    message: "Add stock buys or sells for this asset.",
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

    private var fallbackCategory: String {
        holding.customCategory.isEmpty ? "Unspecified" : holding.customCategory
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

    private func close() {
        if let closeAction {
            closeAction()
        } else {
            dismiss()
        }
    }

    private func priceChartTraceGesture(proxy: ChartProxy, geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                updateSelectedPricePoint(at: value.location, proxy: proxy, geometry: geometry)
            }
    }

    private func updateSelectedPricePoint(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let plotRect = geometry[plotFrame]
        guard plotRect.contains(location) else { return }
        let relativeX = location.x - plotRect.origin.x
        guard let date: Date = proxy.value(atX: relativeX) else { return }
        selectedPricePoint = visiblePricePoints.nearest(to: date, by: \.date)
    }
}

private struct DetailHeaderButton: View {
    let title: String
    let symbol: String
    var isProminent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .frame(minHeight: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isProminent ? WorthlineTheme.accent : WorthlineTheme.textPrimary)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isProminent ? WorthlineTheme.accent.opacity(0.13) : Color.secondary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isProminent ? WorthlineTheme.accent.opacity(0.28) : WorthlineTheme.border, lineWidth: 0.8)
        }
    }
}

private struct DetailTabBar: View {
    @Binding var selection: AssetDetailTab

    var body: some View {
        HStack(spacing: 22) {
            ForEach(AssetDetailTab.allCases) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 7) {
                        Label(tab.rawValue, systemImage: tab.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selection == tab ? WorthlineTheme.textPrimary : WorthlineTheme.textSecondary)
                        Rectangle()
                            .fill(selection == tab ? WorthlineTheme.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(minWidth: 92)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorthlineTheme.border)
                .frame(height: 0.8)
        }
    }
}
