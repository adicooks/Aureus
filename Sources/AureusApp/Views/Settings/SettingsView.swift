import AppKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Holding.name) private var holdings: [Holding]
    @Query(sort: \NetWorthSnapshot.date) private var snapshots: [NetWorthSnapshot]
    @Query private var watchlistItems: [WatchlistItem]
    @Query private var transactions: [Transaction]
    @Query private var settings: [UserSettings]

    let refreshAction: () async -> Void

    @State private var statusMessage: String?
    @State private var showingSampleConfirmation = false
    @State private var showingClearDataConfirmation = false

    private var activeSettings: UserSettings? {
        settings.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                preferences
                dataTools
                privacy
                appInfo
            }
            .padding(28)
        }
        .premiumPageBackground()
        .alert("Load Sample Data?", isPresented: $showingSampleConfirmation) {
            Button("Load", action: loadSampleData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sample assets and snapshots will be added to your local store.")
        }
        .alert("Clear All Local Data?", isPresented: $showingClearDataConfirmation) {
            Button("Clear Everything", role: .destructive, action: clearAllData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes holdings, watchlist symbols, transactions, price history, snapshots, and saved preferences from this Mac.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Settings")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Local data controls, privacy, and portfolio preferences.")
                .font(.callout)
                .foregroundStyle(WorthlineTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var preferences: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Preferences")
                if let activeSettings {
                    Picker("Automatic refresh", selection: Binding(
                        get: { activeSettings.refreshInterval },
                        set: { activeSettings.refreshInterval = $0; try? modelContext.save() }
                    )) {
                        ForEach(RefreshInterval.allCases) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }
                    .controlSize(.large)

                    TextField("Net worth goal", value: Binding(
                        get: { activeSettings.netWorthGoal },
                        set: { activeSettings.netWorthGoal = max(0, $0); try? modelContext.save() }
                    ), format: .number.precision(.fractionLength(0...2)))
                    .aureusFieldStyle()

                    Toggle("Require local app lock", isOn: Binding(
                        get: { activeSettings.requireLocalLock },
                        set: { activeSettings.requireLocalLock = $0; try? modelContext.save() }
                    ))
                    .toggleStyle(.switch)

                    Text("App lock is stored as a local preference and can be activated once signing and distribution settings are finalized.")
                        .font(.caption)
                        .foregroundStyle(WorthlineTheme.textSecondary)
                } else {
                    EmptyStateView(
                        title: "Settings are being prepared",
                        message: "Worthline will create local settings automatically.",
                        symbol: "gearshape"
                    )
                    .frame(height: 220)
                }
            }
        }
    }

    private var dataTools: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Local Data")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    SecondaryButton(title: "Export CSV", symbol: "square.and.arrow.up", action: exportCSV)
                    SecondaryButton(title: "Import CSV", symbol: "square.and.arrow.down", action: importCSV)
                    SecondaryButton(title: "Backup", symbol: "externaldrive", action: exportBackup)
                    SecondaryButton(title: "Restore", symbol: "arrow.clockwise.icloud", action: restoreBackup)
                }
                HStack {
                    PrimaryButton(title: "Refresh Prices Now", symbol: "arrow.clockwise") {
                        Task { await refreshAction() }
                    }
                    SecondaryButton(title: "Load Sample Data", symbol: "wand.and.stars") {
                        showingSampleConfirmation = true
                    }
                    SecondaryButton(title: "Clear Data", symbol: "trash") {
                        showingClearDataConfirmation = true
                    }
                    Spacer()
                }
                if let statusMessage {
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(WorthlineTheme.textSecondary)
                }
            }
        }
    }

    private var privacy: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Privacy")
                Text("Worthline stores holdings, transactions, snapshots, settings, CSV imports, and backups locally on this Mac. Market price refreshes contact Yahoo Finance only for the ticker symbols you choose to track.")
                    .font(.callout)
                    .foregroundStyle(WorthlineTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appInfo: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Product Areas")
                Label("Watchlist uses its own local SwiftData model for non-owned symbols.", systemImage: "eye")
                Label("Transactions support buys, sells, dividends, deposits, withdrawals, interest, and adjustments.", systemImage: "arrow.left.arrow.right")
                Label("Reports and Goals are generated from existing holdings, snapshots, and settings.", systemImage: "chart.bar.doc.horizontal")
            }
            .font(.callout)
            .foregroundStyle(WorthlineTheme.textSecondary)
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "worthline-holdings.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try CSVService.export(holdings: holdings).write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "CSV exported."
        } catch {
            statusMessage = "Unable to export CSV."
        }
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let csv = try String(contentsOf: url, encoding: .utf8)
            let imported = try CSVService.parse(csv)
            let existingTickers = Set(holdings.map(\.ticker).filter { !$0.isEmpty })
            for holding in imported where holding.ticker.isEmpty || !existingTickers.contains(holding.ticker) {
                modelContext.insert(holding)
            }
            try modelContext.save()
            statusMessage = "CSV imported."
        } catch {
            statusMessage = "Unable to import CSV."
        }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "worthline-backup.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try BackupService.encode(holdings: holdings, snapshots: snapshots)
            try data.write(to: url, options: .atomic)
            statusMessage = "Backup exported."
        } catch {
            statusMessage = "Unable to export backup."
        }
    }

    private func restoreBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let backup = try BackupService.decode(Data(contentsOf: url))
            for holding in backup.holdings {
                modelContext.insert(holding.makeHolding())
            }
            for snapshot in backup.snapshots {
                modelContext.insert(snapshot.makeSnapshot())
            }
            try modelContext.save()
            statusMessage = "Backup restored."
        } catch {
            statusMessage = "Unable to restore backup."
        }
    }

    private func loadSampleData() {
        SampleData.holdings.forEach(modelContext.insert)
        SampleData.snapshots.forEach(modelContext.insert)
        try? modelContext.save()
        statusMessage = "Sample data loaded."
    }

    private func clearAllData() {
        transactions.forEach(modelContext.delete)
        holdings.forEach(modelContext.delete)
        snapshots.forEach(modelContext.delete)
        watchlistItems.forEach(modelContext.delete)
        settings.forEach(modelContext.delete)
        modelContext.insert(UserSettings())
        try? modelContext.save()
        statusMessage = "All local data cleared."
    }
}
