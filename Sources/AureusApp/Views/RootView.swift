import SwiftData
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case holdings
    case watchlist
    case transactions
    case performance
    case reports
    case goals
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
        case .goals: "Goals"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "rectangle.grid.2x2"
        case .holdings: "chart.pie"
        case .watchlist: "eye"
        case .transactions: "arrow.left.arrow.right"
        case .performance: "chart.xyaxis.line"
        case .reports: "doc.text.magnifyingglass"
        case .goals: "target"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Holding.name) private var holdings: [Holding]
    @Query(sort: \NetWorthSnapshot.date) private var snapshots: [NetWorthSnapshot]
    @Query private var settings: [UserSettings]

    @State private var selection: AppSection = .dashboard
    @State private var showingAddAsset = false
    @State private var isRefreshing = false
    @State private var message: String?
    @State private var errorMessage: String?

    private let quoteService = YahooFinanceService()

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
            SnapshotService.saveDailySnapshotIfNeeded(holdings: holdings, snapshots: snapshots, context: modelContext)
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
        case .goals:
            GoalsView()
        case .settings:
            SettingsView(refreshAction: refreshPrices)
        }
    }

    @MainActor
    private func refreshPrices() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var failures: [String] = []
        for holding in holdings where holding.kind.isMarketPriced && !holding.ticker.isEmpty {
            do {
                let quote = try await quoteService.fetchQuote(for: holding.ticker)
                holding.apply(price: quote)
                modelContext.insert(PriceSnapshot(price: quote.regularMarketPrice, holding: holding))
            } catch {
                failures.append("\(holding.ticker): \(error.localizedDescription)")
            }
        }

        do {
            try modelContext.save()
            SnapshotService.saveSnapshot(holdings: holdings, context: modelContext, note: "Post-refresh snapshot")
            if failures.isEmpty {
                showMessage("Prices refreshed")
            } else {
                showError("Some prices could not refresh. Cached values remain available.")
            }
        } catch {
            showError("Unable to save refreshed prices.")
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
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(WorthlineTheme.accent)
                    Text("W")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)

                Text("Worthline")
                    .font(.headline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            VStack(spacing: 5) {
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
            .padding(.horizontal, 10)

            Spacer()

            MarketStatusCard(
                holdings: holdings,
                isRefreshing: isRefreshing,
                refreshAction: refreshAction
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .frame(width: 214)
        .background(WorthlineTheme.sidebarBackground)
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
                Image(systemName: section.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                Text(section.title)
                    .font(.callout.weight(.medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? .white : WorthlineTheme.textPrimary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(WorthlineTheme.accent)
                        .matchedGeometryEffect(id: "selected-section", in: namespace)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
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

