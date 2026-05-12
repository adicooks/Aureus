import SwiftData
import SwiftUI

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchlistItem.ticker) private var items: [WatchlistItem]

    @State private var showingEditor = false
    @State private var deleteCandidate: WatchlistItem?
    @State private var priceHistories: [UUID: [HistoricalPricePoint]] = [:]

    private let quoteService = YahooFinanceService()

    private var refreshKey: String {
        items.map {
            [
                $0.id.uuidString,
                $0.ticker
            ].joined(separator: ":")
        }
        .joined(separator: "|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            SectionCard(padding: 0) {
                if items.isEmpty {
                    EmptyStateView(
                        title: "No watchlist items",
                        message: "Track symbols before you buy. Watchlist items are stored locally alongside your portfolio.",
                        symbol: "eye",
                        buttonTitle: "Add Symbol",
                        action: { showingEditor = true }
                    )
                    .frame(minHeight: 520)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { item in
                                WatchlistRow(item: item, history: priceHistories[item.id] ?? []) {
                                    deleteCandidate = item
                                }
                                Divider().opacity(0.55)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .premiumPageBackground()
        .sheet(isPresented: $showingEditor) {
            WatchlistEditorView()
                .frame(minWidth: 420, minHeight: 340)
        }
        .alert("Remove Symbol?", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let deleteCandidate {
                    modelContext.delete(deleteCandidate)
                    try? modelContext.save()
                }
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
        } message: {
            Text("This removes the watchlist item from local storage.")
        }
        .task(id: refreshKey) {
            await refreshWatchlist()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Watchlist")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("\(items.count) symbols under observation")
                    .font(.callout)
                    .foregroundStyle(WorthlineTheme.textSecondary)
            }
            Spacer()
            SecondaryButton(title: "Refresh", symbol: "arrow.clockwise") {
                Task { await refreshWatchlist(force: true) }
            }
            PrimaryButton(title: "Add Symbol", symbol: "plus") {
                showingEditor = true
            }
        }
        .padding([.horizontal, .top], 28)
    }

    @MainActor
    private func refreshWatchlist(force: Bool = false) async {
        for item in items {
            let isStale = item.lastUpdated.map { Date().timeIntervalSince($0) > 900 } ?? true
            let needsProfile = item.name.isEmpty || item.logoURL == nil || item.sector == nil
            let needsHistory = priceHistories[item.id]?.isEmpty ?? true
            guard force || isStale || needsProfile || needsHistory else { continue }

            async let quote = quoteService.fetchQuote(for: item.ticker)
            async let profile = quoteService.fetchProfile(for: item.ticker)
            async let history = quoteService.fetchPriceHistory(
                for: item.ticker,
                from: Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
            )

            if let quote = try? await quote {
                item.apply(quote: quote)
            }
            if let profile = try? await profile {
                item.apply(profile: profile)
            }
            if let history = try? await history {
                priceHistories[item.id] = history
            }
        }
        try? modelContext.save()
    }
}

private struct WatchlistRow: View {
    let item: WatchlistItem
    let history: [HistoricalPricePoint]
    let deleteAction: () -> Void
    @State private var hovering = false

    private var change: Double? {
        guard let latest = item.latestPrice, let previous = item.previousClose else { return nil }
        return latest - previous
    }

    private var chartTint: Color {
        (thirtyDayChange ?? change ?? 0) >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative
    }

    private var subtitle: String {
        let detail = [item.sector, item.industry]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " · ")
        if !detail.isEmpty { return detail }
        return item.name.isEmpty ? "Unlabeled symbol" : item.name
    }

    private var thirtyDayChange: Double? {
        guard let first = history.first?.price, let last = history.last?.price, first > 0 else { return nil }
        return (last - first) / first
    }

    private var statusText: String {
        if item.latestPrice == nil { return "Fetching quote" }
        if item.previousClose == nil { return item.lastUpdated == nil ? "Waiting for market data" : "Latest price only" }
        return item.lastUpdated?.formatted(Formatters.time) ?? "Live quote"
    }

    var body: some View {
        HStack(spacing: 14) {
            LogoTile(
                logoURLString: item.logoURL.flatMap { URL(string: $0) == nil ? nil : $0 },
                fallbackText: item.ticker,
                fallbackTint: WorthlineTheme.accent,
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.ticker)
                    .font(.callout.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(WorthlineTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("30D")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WorthlineTheme.textSecondary)
                Text(thirtyDayChange?.formatted(Formatters.percent) ?? "No history")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(thirtyDayChange == nil ? WorthlineTheme.textSecondary : chartTint)
                    .monospacedDigit()
            }
            .frame(width: 100, alignment: .trailing)
            Text(item.latestPrice?.formatted(Formatters.currency) ?? "No price")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(width: 120, alignment: .trailing)
            if let change {
                GainLossText(amount: change, percent: item.previousClose.map { $0 > 0 ? change / $0 : 0 }, compact: true)
                    .frame(width: 130, alignment: .trailing)
            } else {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(WorthlineTheme.textSecondary)
                    .frame(width: 130, alignment: .trailing)
            }
            Text(item.lastUpdated?.formatted(Formatters.time) ?? "Never")
                .font(.caption)
                .foregroundStyle(WorthlineTheme.textSecondary)
                .frame(width: 90, alignment: .trailing)
            Menu {
                Button("Remove", systemImage: "trash", role: .destructive, action: deleteAction)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 26, height: 26)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 26)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(hovering ? WorthlineTheme.accent.opacity(0.08) : Color.clear)
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Remove", systemImage: "trash", role: .destructive, action: deleteAction)
        }
    }
}

private struct WatchlistEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var ticker = ""
    @State private var note = ""
    @State private var validationMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case ticker
        case note
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                SectionCard {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Ticker", text: $ticker)
                            .aureusFieldStyle()
                            .focused($focusedField, equals: .ticker)
                            .onChange(of: ticker) { _, newValue in ticker = newValue.uppercased() }
                        TextField("Note", text: $note)
                            .aureusFieldStyle()
                            .focused($focusedField, equals: .note)
                    }
                }
                if let validationMessage {
                    Text(validationMessage)
                        .font(.callout)
                        .foregroundStyle(WorthlineTheme.negative)
                }
                Spacer()
            }
            .padding(22)
            .premiumPageBackground()
            .navigationTitle("Add Symbol")
            .onAppear { focusedField = .ticker }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func save() {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanTicker.isEmpty else {
            validationMessage = "Ticker is required."
            return
        }
        modelContext.insert(WatchlistItem(ticker: cleanTicker, note: note))
        try? modelContext.save()
        dismiss()
    }
}
