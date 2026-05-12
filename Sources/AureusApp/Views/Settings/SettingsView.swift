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
    @State private var showingClearSnapshotsConfirmation = false
    @State private var showingPasteImport = false
    @State private var pastedCSV = ""

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
        .alert("Load Random Data?", isPresented: $showingSampleConfirmation) {
            Button("Load", action: loadRandomData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Randomized assets and snapshots will be added to your local store.")
        }
        .alert("Clear All Local Data?", isPresented: $showingClearDataConfirmation) {
            Button("Clear Everything", role: .destructive, action: clearAllData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes holdings, watchlist symbols, transactions, price history, snapshots, and saved preferences from this Mac.")
        }
        .alert("Remove All Snapshots?", isPresented: $showingClearSnapshotsConfirmation) {
            Button("Remove Snapshots", role: .destructive, action: clearSnapshots)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes saved net worth snapshots. Holdings, watchlist symbols, and transactions stay untouched.")
        }
        .sheet(isPresented: $showingPasteImport) {
            CSVPasteImportView(csvText: $pastedCSV) {
                importCSVText(pastedCSV)
                pastedCSV = ""
                showingPasteImport = false
            }
            .frame(minWidth: 640, minHeight: 520)
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
                HStack(spacing: 10) {
                    SecondaryButton(title: "Export CSV", symbol: "square.and.arrow.up", action: exportCSV)
                    SecondaryButton(title: "Import CSV", symbol: "square.and.arrow.down", action: importCSV)
                    SecondaryButton(title: "Paste CSV", symbol: "doc.on.clipboard") {
                        pastedCSV = ""
                        showingPasteImport = true
                    }
                    SecondaryButton(title: "Backup", symbol: "externaldrive", action: exportBackup)
                    SecondaryButton(title: "Restore", symbol: "arrow.clockwise.icloud", action: restoreBackup)
                    SecondaryButton(title: "Load Random Data", symbol: "wand.and.stars") {
                        showingSampleConfirmation = true
                    }
                    SecondaryButton(title: "Remove Snapshots", symbol: "camera.on.rectangle") {
                        showingClearSnapshotsConfirmation = true
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
                Label("Reports are generated from existing holdings, snapshots, and settings.", systemImage: "chart.bar.doc.horizontal")
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
            importCSVText(csv)
        } catch {
            statusMessage = "Unable to import CSV."
        }
    }

    private func importCSVText(_ csv: String) {
        do {
            let imported = try CSVService.parse(csv)
            var insertedCount = 0
            for holding in imported {
                modelContext.insert(holding)
                modelContext.insert(initialImportTransaction(for: holding))
                if let saleTransaction = saleImportTransaction(for: holding) {
                    modelContext.insert(saleTransaction)
                }
                insertedCount += 1
            }
            try modelContext.save()
            statusMessage = insertedCount == 1 ? "1 holding imported." : "\(insertedCount) holdings imported."
        } catch {
            statusMessage = "Unable to import CSV."
        }
    }

    private func initialImportTransaction(for holding: Holding) -> Transaction {
        Transaction(
            kind: .buy,
            date: holding.purchaseDate,
            quantity: holding.kind.isMarketPriced ? holding.quantity : 0,
            price: holding.kind.isMarketPriced ? holding.purchasePrice : holding.currentValue,
            fees: holding.fees,
            note: "Imported buy",
            holding: holding
        )
    }

    private func saleImportTransaction(for holding: Holding) -> Transaction? {
        guard holding.isArchived else { return nil }
        let details = importedSaleDetails(from: holding.notes)
        return Transaction(
            kind: .sell,
            date: details.date ?? holding.updatedAt,
            quantity: holding.kind.isMarketPriced ? holding.quantity : 0,
            price: details.price ?? holding.purchasePrice,
            fees: 0,
            note: holding.notes.isEmpty ? "Imported sale" : holding.notes,
            holding: holding
        )
    }

    private func importedSaleDetails(from notes: String) -> (date: Date?, price: Double?) {
        let pattern = #"(?i)sold\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4})\s+at\s+\$?([0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: notes, range: NSRange(notes.startIndex..., in: notes)) else {
            return (nil, nil)
        }

        let date = Range(match.range(at: 1), in: notes)
            .map { parseImportDate(String(notes[$0])) } ?? nil
        let price = Range(match.range(at: 2), in: notes)
            .flatMap { Double(notes[$0]) }
        return (date, price)
    }

    private func parseImportDate(_ value: String) -> Date? {
        for format in ["M/d/yyyy", "MM/dd/yyyy"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
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

    private func loadRandomData() {
        SampleData.holdings.map(randomizedHolding).forEach(modelContext.insert)
        randomizedSnapshots().forEach(modelContext.insert)
        try? modelContext.save()
        statusMessage = "Random data loaded."
    }

    private func randomizedHolding(from sample: Holding) -> Holding {
        let purchaseDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 14...900), to: .now) ?? sample.purchaseDate
        return Holding(
            kind: sample.kind,
            name: sample.name,
            ticker: sample.ticker,
            quantity: sample.quantity,
            purchaseDate: purchaseDate,
            purchasePrice: sample.purchasePrice,
            fees: sample.fees,
            notes: sample.notes,
            principalAmount: sample.principalAmount,
            interestRate: sample.interestRate,
            maturityDate: sample.maturityDate,
            customCategory: sample.customCategory,
            manualCurrentValue: sample.manualCurrentValue,
            latestPrice: sample.latestPrice,
            previousClose: sample.previousClose,
            lastPriceUpdate: sample.lastPriceUpdate
        )
    }

    private func randomizedSnapshots() -> [NetWorthSnapshot] {
        stride(from: 11, through: 0, by: -1).map { offset in
            let baseDate = Calendar.current.date(byAdding: .month, value: -offset, to: .now) ?? .now
            let date = Calendar.current.date(byAdding: .day, value: Int.random(in: -8...8), to: baseDate) ?? baseDate
            let value = 185_000 + Double(11 - offset) * Double.random(in: 6_500...8_800) + Double.random(in: -5_000...5_000)
            return NetWorthSnapshot(
                date: min(date, .now),
                totalValue: value,
                investedAmount: value * Double.random(in: 0.76...0.88),
                unrealizedGainLoss: value * Double.random(in: 0.10...0.24),
                note: "Random"
            )
        }
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

    private func clearSnapshots() {
        snapshots.forEach(modelContext.delete)
        try? modelContext.save()
        statusMessage = "All snapshots removed."
    }
}

private struct CSVPasteImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var csvText: String
    let importAction: () -> Void

    private let placeholder = """
    kind,name,ticker,quantity,purchaseDate,purchasePrice,fees,currentValue,notes
    stock,Apple,AAPL,10,2025-01-15T00:00:00Z,185,0,0,Long term
    cash,Emergency Fund,,0,2025-01-15T00:00:00Z,5000,0,5000,High yield savings
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paste CSV")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text("Paste the same holdings CSV format used by file import.")
                        .font(.callout)
                        .foregroundStyle(WorthlineTheme.textSecondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            ZStack(alignment: .topLeading) {
                if csvText.isEmpty {
                    Text(placeholder)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(WorthlineTheme.textSecondary.opacity(0.55))
                        .padding(18)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $csvText)
                    .font(.system(.callout, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color.clear)
            }
            .background(WorthlineTheme.fieldBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(WorthlineTheme.border, lineWidth: 0.8)
            }

            HStack {
                Spacer()
                SecondaryButton(title: "Cancel", symbol: "xmark") {
                    dismiss()
                }
                PrimaryButton(title: "Import", symbol: "square.and.arrow.down", action: importAction)
                    .disabled(csvText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .premiumPageBackground()
    }
}
