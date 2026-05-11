import SwiftData
import SwiftUI

enum HoldingSort: String, CaseIterable, Identifiable {
    case marketValue
    case gainLoss
    case gainPercent
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .marketValue: "Market Value"
        case .gainLoss: "Gain/Loss"
        case .gainPercent: "Gain %"
        case .name: "Name"
        }
    }
}

enum HoldingFilter: String, CaseIterable, Hashable {
    case all = "All"
    case stock = "Stocks"
    case etf = "ETFs"
    case bond = "Bonds"
    case cash = "Cash"
    case crypto = "Crypto"
    case other = "Other"

    func includes(_ kind: AssetKind) -> Bool {
        switch self {
        case .all: true
        case .stock: kind == .stock
        case .etf: kind == .etf
        case .bond: kind == .bond
        case .cash: kind == .cash
        case .crypto: kind == .crypto
        case .other: ![.stock, .etf, .bond, .cash, .crypto].contains(kind)
        }
    }
}

struct HoldingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Holding.name) private var holdings: [Holding]

    let isRefreshing: Bool
    let refreshAction: () async -> Void
    let addAction: () -> Void

    @State private var searchText = ""
    @State private var filter: HoldingFilter = .all
    @State private var sort: HoldingSort = .marketValue
    @State private var selectedHolding: Holding?
    @State private var editingHolding: Holding?
    @State private var deleteCandidate: Holding?

    private var summary: PortfolioSummary {
        PortfolioCalculator.summarize(holdings)
    }

    private var filteredMetrics: [HoldingMetrics] {
        var metrics = summary.metrics.filter { filter.includes($0.holding.kind) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            metrics = metrics.filter {
                $0.holding.name.localizedCaseInsensitiveContains(query)
                || $0.holding.ticker.localizedCaseInsensitiveContains(query)
                || $0.holding.kind.title.localizedCaseInsensitiveContains(query)
            }
        }

        switch sort {
        case .marketValue:
            return metrics.sorted { $0.currentValue > $1.currentValue }
        case .gainLoss:
            return metrics.sorted { $0.gainLoss > $1.gainLoss }
        case .gainPercent:
            return metrics.sorted { $0.gainLossPercent > $1.gainLossPercent }
        case .name:
            return metrics.sorted { $0.holding.name.localizedCaseInsensitiveCompare($1.holding.name) == .orderedAscending }
        }
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 18) {
                header

                if holdings.isEmpty {
                    SectionCard {
                        EmptyStateView(
                            title: "No holdings yet",
                            message: "Add assets manually or import a CSV to begin tracking your portfolio.",
                            symbol: "tray",
                            buttonTitle: "Add Asset",
                            action: addAction
                        )
                        .frame(minHeight: 480)
                    }
                    .padding(.horizontal, 28)
                } else {
                    controls
                    HoldingsTable(
                        metrics: filteredMetrics,
                        summary: summary,
                        openAction: { selectedHolding = $0 },
                        editAction: { editingHolding = $0 },
                        deleteAction: { deleteCandidate = $0 }
                    )
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }

            if let selectedHolding {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture {
                        self.selectedHolding = nil
                    }

                AssetDetailView(holding: selectedHolding, closeAction: { self.selectedHolding = nil })
                    .frame(width: 900, height: 720)
                    .background(WorthlineTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(WorthlineTheme.border, lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 30, y: 18)
                    .padding(36)
            }
        }
        .premiumPageBackground()
        .sheet(item: $editingHolding) { holding in
            AssetEditorView(holding: holding)
                .frame(minWidth: 560, minHeight: 620)
        }
        .alert("Delete Asset?", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let deleteCandidate {
                    modelContext.delete(deleteCandidate)
                    try? modelContext.save()
                }
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) {
                deleteCandidate = nil
            }
        } message: {
            Text("This removes the holding, transactions, and local price history. This cannot be undone.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Holdings")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("\(holdings.count) assets · \(summary.totalNetWorth.formatted(Formatters.currency))")
                    .font(.callout)
                    .foregroundStyle(WorthlineTheme.textSecondary)
            }
            Spacer()
            SecondaryButton(title: isRefreshing ? "Refreshing" : "Refresh", symbol: "arrow.clockwise") {
                Task { await refreshAction() }
            }
            PrimaryButton(title: "Add Asset", symbol: "plus", action: addAction)
        }
        .padding([.horizontal, .top], 28)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SearchField(placeholder: "Search holdings...", text: $searchText)
                    .frame(width: 320)
                Spacer()
                SortMenu(selection: $sort)
            }

            FilterPills(options: HoldingFilter.allCases, selection: $filter) { filter in
                Text(filter.rawValue)
            }
        }
        .padding(.horizontal, 28)
    }
}

struct HoldingsTable: View {
    let metrics: [HoldingMetrics]
    let summary: PortfolioSummary
    let openAction: (Holding) -> Void
    let editAction: (Holding) -> Void
    let deleteAction: (Holding) -> Void

    var body: some View {
        SectionCard(padding: 0) {
            VStack(spacing: 0) {
                tableHeader

                if metrics.isEmpty {
                    EmptyStateView(
                        title: "Nothing matches that view",
                        message: "Adjust search or filters to see more holdings.",
                        symbol: "magnifyingglass"
                    )
                    .frame(minHeight: 390)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(metrics) { metric in
                                HoldingTableRow(
                                    metric: metric,
                                    openAction: { openAction(metric.holding) },
                                    editAction: { editAction(metric.holding) },
                                    deleteAction: { deleteAction(metric.holding) }
                                )
                                Divider().opacity(0.55)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }

                totalRow
            }
            .frame(maxHeight: 560, alignment: .top)
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            tableLabel("Asset", alignment: .leading).frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
            tableLabel("Quantity").frame(width: 105, alignment: .trailing)
            tableLabel("Market Value").frame(width: 140, alignment: .trailing)
            tableLabel("Gain/Loss").frame(width: 135, alignment: .trailing)
            tableLabel("Gain %").frame(width: 90, alignment: .trailing)
            tableLabel("Day Change").frame(width: 115, alignment: .center)
            Color.clear.frame(width: 26)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08))
        .frame(height: 48)
    }

    private var totalRow: some View {
        HStack(spacing: 12) {
            Text("Total")
                .font(.callout.weight(.bold))
                .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: 105)
            Text(summary.totalNetWorth, format: Formatters.currency)
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .frame(width: 140, alignment: .trailing)
            GainLossText(amount: summary.unrealizedGainLoss, percent: nil, compact: true)
                .frame(width: 135, alignment: .trailing)
            Text(summary.unrealizedGainLossPercent, format: Formatters.percent)
                .font(.caption.weight(.bold))
                .foregroundStyle(summary.unrealizedGainLoss >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)
            GainLossText(amount: summary.dailyChange ?? 0, percent: summary.dailyChangePercent, compact: true)
                .frame(width: 115, alignment: .center)
            Color.clear.frame(width: 26)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
        .frame(height: 54)
    }

    private func tableLabel(_ text: String, alignment: Alignment = .trailing) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(WorthlineTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

private struct SortMenu: View {
    @Binding var selection: HoldingSort

    var body: some View {
        Menu {
            ForEach(HoldingSort.allCases) { sort in
                Button {
                    selection = sort
                } label: {
                    if selection == sort {
                        Label(sort.title, systemImage: "checkmark")
                    } else {
                        Text(sort.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WorthlineTheme.textSecondary)
                Text(selection.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WorthlineTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(width: 172, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(WorthlineTheme.border, lineWidth: 0.8)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

private struct HoldingTableRow: View {
    let metric: HoldingMetrics
    let openAction: () -> Void
    let editAction: () -> Void
    let deleteAction: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: openAction) {
            HStack(spacing: 12) {
                HStack(spacing: 11) {
                    AssetIcon(holding: metric.holding)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metric.holding.name)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        Text("\(metric.holding.displayTicker) · \(metric.holding.kind.singularTitle)")
                            .font(.caption)
                            .foregroundStyle(WorthlineTheme.textSecondary)
                    }
                }
                .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)

                Text(quantityText)
                    .frame(width: 105, alignment: .trailing)
                Text(metric.currentValue, format: Formatters.currency)
                    .frame(width: 140, alignment: .trailing)
                GainLossText(amount: metric.gainLoss, percent: nil, compact: true)
                    .frame(width: 135, alignment: .trailing)
                Text(metric.gainLossPercent, format: Formatters.percent)
                    .foregroundStyle(metric.gainLoss >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
                    .frame(width: 90, alignment: .trailing)
                GainLossText(amount: metric.holding.dailyChange ?? 0, percent: dayChangePercent, compact: true)
                    .frame(width: 115, alignment: .center)

                Menu {
                    Button("Edit", systemImage: "pencil", action: editAction)
                    Button("Delete", systemImage: "trash", role: .destructive, action: deleteAction)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 26)
            }
            .font(.callout)
            .monospacedDigit()
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(hovering ? WorthlineTheme.accent.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var quantityText: String {
        metric.holding.kind == .bond
        ? metric.holding.principalAmount.formatted(Formatters.currency)
        : metric.holding.quantity.formatted(Formatters.number)
    }

    private var dayChangePercent: Double? {
        guard let previous = metric.holding.previousValue, previous > 0, let dailyChange = metric.holding.dailyChange else { return nil }
        return dailyChange / previous
    }
}
