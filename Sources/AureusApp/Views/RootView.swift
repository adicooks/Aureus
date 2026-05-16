import SwiftData
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case holdings
    case watchlist
    case transactions
    case performance
    case reports
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .holdings: "Holdings"
        case .watchlist: "Watchlist"
        case .transactions: "Transactions"
        case .performance: "Performance"
        case .reports: "Reports"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "building.columns"
        case .holdings: "square.grid.3x3"
        case .watchlist: "dot.radiowaves.left.and.right"
        case .transactions: "arrow.left.arrow.right"
        case .performance: "chart.bar.xaxis"
        case .reports: "doc.text"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Holding.name) private var holdings: [Holding]
    @Query(sort: \NetWorthSnapshot.date) private var snapshots: [NetWorthSnapshot]
    @Query private var transactions: [Transaction]
    @Query private var settings: [UserSettings]

    @State private var selection: AppSection = .dashboard
    @State private var showingAddAsset = false
    @State private var isRefreshing = false
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var lastMarketAutoRefresh: Date?

    private let quoteService = YahooFinanceService()
    private let marketAutoRefreshInterval: TimeInterval = 900
    private let marketAutoRefreshCheckInterval: TimeInterval = 60

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(
                selection: $selection,
                holdings: holdings,
                isRefreshing: isRefreshing,
                refreshAction: refreshPrices
            )

            ZStack(alignment: .bottom) {
                detail
                    .id(selection)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

                if let message {
                    StatusToast(message: message, symbol: "checkmark.circle.fill", tint: WorthlineTheme.positive)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let errorMessage {
                    StatusToast(message: errorMessage, symbol: "exclamationmark.triangle.fill", tint: WorthlineTheme.warning)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(WorthlineTheme.background)
        .tint(WorthlineTheme.accent)
        .sheet(isPresented: $showingAddAsset) {
            AssetEditorView()
                .frame(minWidth: 560, minHeight: 620)
        }
        .task {
            ensureSettings()
            seedSampleDataIfRequested()
            backfillInitialTransactionsIfNeeded()
            SnapshotService.saveDailySnapshotIfNeeded(holdings: holdings, snapshots: snapshots, context: modelContext)
        }
        .task {
            await runMarketAutoRefreshLoop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .aureusAddAsset)) { _ in
            showingAddAsset = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .aureusRefreshPrices)) { _ in
            Task { await refreshPrices() }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .dashboard:
            DashboardView(isRefreshing: isRefreshing, refreshAction: refreshPrices, addAction: { showingAddAsset = true })
        case .holdings:
            HoldingsView(isRefreshing: isRefreshing, refreshAction: refreshPrices, addAction: { showingAddAsset = true })
        case .watchlist:
            WatchlistView()
        case .transactions:
            TransactionsView()
        case .performance:
            PerformanceView(snapshotAction: createManualSnapshot)
        case .reports:
            ReportsView()
        case .settings:
            SettingsView(refreshAction: refreshPrices)
        }
    }

    @MainActor
    private func refreshPrices() async {
        await refreshPrices(showStatus: true)
    }

    @MainActor
    private func refreshPrices(showStatus: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var failures: [String] = []
        for holding in holdings where holding.kind.isMarketPriced && !holding.ticker.isEmpty {
            do {
                let quote = try await quoteService.fetchQuote(for: holding.ticker)
                holding.apply(price: quote)
                if let historyStart = Calendar.current.date(byAdding: .year, value: -1, to: .now) {
                    if let history = try? await quoteService.fetchPriceHistory(for: holding.ticker, from: min(holding.purchaseDate, historyStart)) {
                        insertMissingSnapshots(history, for: holding)
                    }
                }
                modelContext.insert(PriceSnapshot(price: quote.regularMarketPrice, holding: holding))
            } catch {
                failures.append("\(holding.ticker): \(error.localizedDescription)")
            }
        }
        await refreshProfilesForRefreshableHoldings()

        do {
            try modelContext.save()
            SnapshotService.saveSnapshot(holdings: holdings, context: modelContext, note: "Post-refresh snapshot")
            if failures.isEmpty, showStatus {
                showMessage("Prices refreshed")
            } else if !failures.isEmpty, showStatus {
                showError("Some prices could not refresh. Cached values remain available.")
            }
        } catch {
            if showStatus {
                showError("Unable to save refreshed prices.")
            }
        }
    }

    @MainActor
    private func runMarketAutoRefreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(marketAutoRefreshCheckInterval))
            guard !Task.isCancelled else { return }
            if isRegularMarketOpen, shouldRunMarketAutoRefresh {
                await refreshPrices(showStatus: false)
                lastMarketAutoRefresh = .now
            }
        }
    }

    private var shouldRunMarketAutoRefresh: Bool {
        guard !isRefreshing else { return false }
        guard let lastMarketAutoRefresh else { return true }
        return lastMarketAutoRefresh.timeIntervalSinceNow <= -marketAutoRefreshInterval
    }

    private var isRegularMarketOpen: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: .now)
        guard let weekday = components.weekday, let hour = components.hour, let minute = components.minute else { return false }
        let minutes = hour * 60 + minute
        return (2...6).contains(weekday) && minutes >= 570 && minutes < 960
    }

    @MainActor
    private func refreshProfilesForRefreshableHoldings() async {
        let requests = holdings.compactMap { holding -> (UUID, String)? in
            guard holding.kind.isMarketPriced, !holding.ticker.isEmpty else { return nil }
            return (holding.id, holding.ticker)
        }
        guard !requests.isEmpty else { return }

        var profilesByID: [UUID: MarketAssetProfile] = [:]
        await withTaskGroup(of: (UUID, MarketAssetProfile)?.self) { group in
            for request in requests {
                group.addTask {
                    let service = YahooFinanceService()
                    guard let profile = try? await service.fetchProfile(for: request.1) else { return nil }
                    return (request.0, profile)
                }
            }
            for await result in group {
                if let result {
                    profilesByID[result.0] = result.1
                }
            }
        }

        for holding in holdings {
            guard let profile = profilesByID[holding.id] else { continue }
            holding.apply(profile: profile, updateName: holding.name == holding.ticker)
        }
    }

    private func createManualSnapshot() {
        SnapshotService.saveSnapshot(holdings: holdings, context: modelContext)
        showMessage("Snapshot saved")
    }

    private func ensureSettings() {
        if settings.isEmpty {
            modelContext.insert(UserSettings())
            try? modelContext.save()
        }
    }

    private func seedSampleDataIfRequested() {
        guard ProcessInfo.processInfo.environment["AUREUS_SEED_SAMPLE_DATA"] == "1", holdings.isEmpty else { return }
        SampleData.holdings.forEach(modelContext.insert)
        SampleData.snapshots.forEach(modelContext.insert)
        try? modelContext.save()
    }

    private func backfillInitialTransactionsIfNeeded() {
        var insertedAny = false
        for holding in holdings where !holding.isArchived {
            let hasTransaction = transactions.contains { $0.holding?.id == holding.id }
            guard !hasTransaction else { continue }
            modelContext.insert(Transaction(
                kind: .buy,
                date: holding.purchaseDate,
                quantity: holding.kind.isMarketPriced ? holding.quantity : 0,
                price: initialTransactionPrice(for: holding),
                fees: holding.fees,
                note: "Initial position",
                holding: holding
            ))
            insertedAny = true
        }
        if insertedAny {
            try? modelContext.save()
        }
    }

    private func initialTransactionPrice(for holding: Holding) -> Double {
        if holding.kind.isMarketPriced {
            return holding.purchasePrice
        }
        if holding.kind == .bond {
            return holding.purchasePrice > 0 ? holding.purchasePrice : holding.principalAmount
        }
        return holding.purchasePrice > 0 ? holding.purchasePrice : holding.manualCurrentValue
    }

    private func insertMissingSnapshots(_ history: [HistoricalPricePoint], for holding: Holding) {
        let calendar = Calendar.current
        for point in history {
            let alreadyExists = holding.priceSnapshots.contains { calendar.isDate($0.date, inSameDayAs: point.date) }
            if !alreadyExists {
                modelContext.insert(PriceSnapshot(date: point.date, price: point.price, holding: holding))
            }
        }
    }

    private func showMessage(_ text: String) {
        withAnimation { message = text; errorMessage = nil }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation { message = nil }
        }
    }

    private func showError(_ text: String) {
        withAnimation { errorMessage = text; message = nil }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.4))
            withAnimation { errorMessage = nil }
        }
    }
}

struct AppSidebar: View {
    @Binding var selection: AppSection
    let holdings: [Holding]
    let isRefreshing: Bool
    let refreshAction: () async -> Void
    @Namespace private var selectionAnimation

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                BrandMark()
                Text("Aureus")
                    .font(.system(size: 25, weight: .medium, design: .rounded))
            }
            .padding(.leading, 31)
            .padding(.trailing, 24)
            .padding(.top, 34)
            .padding(.bottom, 18)

            VStack(spacing: 12) {
                ForEach(AppSection.allCases) { section in
                    SidebarItem(
                        section: section,
                        isSelected: selection == section,
                        namespace: selectionAnimation
                    ) {
                        withAnimation(.snappy(duration: 0.24)) {
                            selection = section
                        }
                    }
                }
            }
            .padding(.horizontal, 18)

            Spacer()

            MarketStatusCard(
                holdings: holdings,
                isRefreshing: isRefreshing,
                refreshAction: refreshAction
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .frame(width: 254)
        .background {
            WorthlineTheme.sidebarBackground
                .overlay {
                    LinearGradient(
                        colors: [Color.white.opacity(0.035), Color.clear, Color.black.opacity(0.24)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(WorthlineTheme.border)
                .frame(width: 1)
        }
    }
}

struct SidebarItem: View {
    let section: AppSection
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.13) : Color.secondary.opacity(0.08))
                    Image(systemName: section.symbol)
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(width: 28, height: 28)
                Text(section.title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? .white : WorthlineTheme.textPrimary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.58))
                        .overlay {
                            LinearGradient(colors: [Color.white.opacity(0.055), Color.clear], startPoint: .top, endPoint: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .matchedGeometryEffect(id: "selected-section", in: namespace)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.055))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct BrandMark: View {
    private let columns = Array(repeating: GridItem(.fixed(4), spacing: 3), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(0..<16, id: \.self) { index in
                Circle()
                    .fill(index % 3 == 0 ? WorthlineTheme.accent : Color.white.opacity(0.82))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(width: 28, height: 28)
    }
}

struct StatusToast: View {
    let message: String
    let symbol: String
    let tint: Color

    var body: some View {
        Label(message, systemImage: symbol)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.28)))
            .shadow(radius: 12, y: 6)
            .foregroundStyle(.primary)
    }
}
