import SwiftData
import SwiftUI

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchlistItem.ticker) private var items: [WatchlistItem]

    @State private var showingEditor = false
    @State private var deleteCandidate: WatchlistItem?

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
                                WatchlistRow(item: item) {
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
            PrimaryButton(title: "Add Symbol", symbol: "plus") {
                showingEditor = true
            }
        }
        .padding([.horizontal, .top], 28)
    }
}

private struct WatchlistRow: View {
    let item: WatchlistItem
    let deleteAction: () -> Void
    @State private var hovering = false

    private var change: Double? {
        guard let latest = item.latestPrice, let previous = item.previousClose else { return nil }
        return latest - previous
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(WorthlineTheme.accentSoft)
                Text(String(item.ticker.prefix(2)))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WorthlineTheme.accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.ticker)
                    .font(.callout.weight(.bold))
                Text(item.name.isEmpty ? "Unlabeled symbol" : item.name)
                    .font(.caption)
                    .foregroundStyle(WorthlineTheme.textSecondary)
            }
            Spacer()
            Text(item.latestPrice?.formatted(Formatters.currency) ?? "No price")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(width: 120, alignment: .trailing)
            if let change {
                GainLossText(amount: change, percent: item.previousClose.map { $0 > 0 ? change / $0 : 0 }, compact: true)
                    .frame(width: 130, alignment: .trailing)
            } else {
                Text("Awaiting update")
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
            .frame(width: 26)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(hovering ? WorthlineTheme.accent.opacity(0.08) : Color.clear)
        .onHover { hovering = $0 }
    }
}

private struct WatchlistEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var ticker = ""
    @State private var name = ""
    @State private var note = ""
    @State private var validationMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case ticker
        case name
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
                        TextField("Name", text: $name)
                            .aureusFieldStyle()
                            .focused($focusedField, equals: .name)
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
        modelContext.insert(WatchlistItem(ticker: cleanTicker, name: name, note: note))
        try? modelContext.save()
        dismiss()
    }
}
