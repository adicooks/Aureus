import SwiftData
import SwiftUI

struct AssetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Holding.name) private var allHoldings: [Holding]

    private let holding: Holding?

    @State private var kind: AssetKind
    @State private var name: String
    @State private var ticker: String
    @State private var quantity: Double
    @State private var purchaseDate: Date
    @State private var purchasePrice: Double
    @State private var fees: Double
    @State private var notes: String
    @State private var principalAmount: Double
    @State private var interestRate: Double
    @State private var maturityDate: Date
    @State private var customCategory: String
    @State private var manualCurrentValue: Double
    @State private var sector: String
    @State private var industry: String
    @State private var dividendYield: Double?
    @State private var earningsDate: String
    @State private var website: String
    @State private var logoURL: String
    @State private var exchangeName: String
    @State private var currencyCode: String
    @State private var validationMessage: String?
    @State private var lookupMessage: String?
    @State private var isLookingUp = false
    @State private var lookupTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    private let quoteService = YahooFinanceService()

    private enum Field: Hashable {
        case name
        case ticker
        case category
        case notes
    }

    init(holding: Holding? = nil) {
        self.holding = holding
        _kind = State(initialValue: holding?.kind ?? .stock)
        _name = State(initialValue: holding?.name ?? "")
        _ticker = State(initialValue: holding?.ticker ?? "")
        _quantity = State(initialValue: holding?.quantity ?? 0)
        _purchaseDate = State(initialValue: holding?.purchaseDate ?? .now)
        _purchasePrice = State(initialValue: holding?.purchasePrice ?? 0)
        _fees = State(initialValue: holding?.fees ?? 0)
        _notes = State(initialValue: holding?.notes ?? "")
        _principalAmount = State(initialValue: holding?.principalAmount ?? 0)
        _interestRate = State(initialValue: holding?.interestRate ?? 0)
        _maturityDate = State(initialValue: holding?.maturityDate ?? .now.addingTimeInterval(86400 * 365))
        _customCategory = State(initialValue: holding?.customCategory ?? "")
        _manualCurrentValue = State(initialValue: holding?.manualCurrentValue ?? 0)
        _sector = State(initialValue: holding?.sector ?? "")
        _industry = State(initialValue: holding?.industry ?? "")
        _dividendYield = State(initialValue: holding?.dividendYield)
        _earningsDate = State(initialValue: holding?.earningsDate ?? "")
        _website = State(initialValue: holding?.website ?? "")
        _logoURL = State(initialValue: holding?.logoURL ?? "")
        _exchangeName = State(initialValue: holding?.exchangeName ?? "")
        _currencyCode = State(initialValue: holding?.currencyCode ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    assetType
                    details
                    valueSection
                    notesSection

                    if let validationMessage {
                        Text(validationMessage)
                            .foregroundStyle(WorthlineTheme.negative)
                            .font(.callout.weight(.medium))
                    }
                }
                .padding(22)
            }
            .premiumPageBackground()
            .navigationTitle(holding == nil ? "Add Asset" : "Edit Asset")
            .onAppear { focusedField = .name }
            .onDisappear { lookupTask?.cancel() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private var assetType: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Asset Type")
                Picker("Type", selection: $kind) {
                    ForEach(AssetKind.allCases) { kind in
                        Label(kind.singularTitle, systemImage: kind.symbol).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var details: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Details")
                TextField("Name", text: $name)
                    .aureusFieldStyle()
                    .focused($focusedField, equals: .name)
                if kind.isMarketPriced {
                    TextField("Ticker", text: $ticker)
                        .aureusFieldStyle()
                        .focused($focusedField, equals: .ticker)
                        .onChange(of: ticker) { _, newValue in
                            let cleanTicker = newValue.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                            if cleanTicker != newValue {
                                ticker = cleanTicker
                            } else {
                                scheduleTickerLookup(for: cleanTicker)
                            }
                        }
                        .onSubmit { scheduleTickerLookup(for: ticker, delay: .zero) }
                    marketProfilePreview
                }
                if kind == .custom || kind == .collectible || kind == .business || kind == .realEstate {
                    TextField("Category", text: $customCategory)
                        .aureusFieldStyle()
                        .focused($focusedField, equals: .category)
                }
                DatePicker(kind == .bond ? "Purchase Date" : "Date Added", selection: $purchaseDate, displayedComponents: .date)
                    .controlSize(.large)
            }
        }
    }

    @ViewBuilder
    private var valueSection: some View {
        if kind == .bond {
            SectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Bond Terms")
                    currencyField("Principal", value: $principalAmount)
                    currencyField("Purchase Price", value: $purchasePrice)
                    percentField("Interest Rate", value: $interestRate)
                    DatePicker("Maturity", selection: $maturityDate, displayedComponents: .date)
                        .controlSize(.large)
                    currencyField("Current Value", value: $manualCurrentValue)
                }
            }
        } else if kind.isMarketPriced {
            SectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Position")
                    numberField("Quantity", value: $quantity)
                    currencyField("Purchase Price", value: $purchasePrice)
                }
            }
        } else {
            SectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Value")
                    currencyField("Cost Basis", value: $purchasePrice)
                    currencyField("Current Value", value: $manualCurrentValue)
                    currencyField("Fees", value: $fees)
                }
            }
        }
    }

    private var notesSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Notes")
                TextEditor(text: $notes)
                    .frame(minHeight: 88)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(WorthlineTheme.fieldBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(WorthlineTheme.border, lineWidth: 0.8)
                    }
                    .focused($focusedField, equals: .notes)
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            validationMessage = "Name is required."
            return
        }
        if kind.isMarketPriced {
            guard !cleanTicker.isEmpty else {
                validationMessage = "Ticker is required for market-tracked assets."
                return
            }
            guard quantity > 0, purchasePrice >= 0 else {
                validationMessage = "Quantity must be greater than zero."
                return
            }
            let duplicate = allHoldings.contains { other in
                other.id != holding?.id && other.kind == kind && other.ticker == cleanTicker
            }
            guard !duplicate else {
                validationMessage = "That ticker is already in your holdings. Edit the existing asset or use advanced lots later."
                return
            }
        }
        if kind == .bond, principalAmount <= 0 {
            validationMessage = "Bond principal must be greater than zero."
            return
        }
        if !kind.isMarketPriced && kind != .bond, manualCurrentValue < 0 {
            validationMessage = "Current value cannot be negative."
            return
        }

        let isNewHolding = holding == nil
        let target = holding ?? Holding(kind: kind, name: cleanName)
        target.kind = kind
        target.name = cleanName
        target.ticker = cleanTicker
        target.quantity = quantity
        target.purchaseDate = purchaseDate
        target.purchasePrice = purchasePrice
        target.fees = kind.isMarketPriced ? 0 : fees
        target.notes = notes
        target.principalAmount = principalAmount
        target.interestRate = interestRate
        target.maturityDate = kind == .bond ? maturityDate : nil
        target.customCategory = customCategory
        target.manualCurrentValue = manualCurrentValue
        target.sector = nilIfBlank(sector)
        target.industry = nilIfBlank(industry)
        target.dividendYield = dividendYield
        target.earningsDate = nilIfBlank(earningsDate)
        target.website = nilIfBlank(website)
        target.logoURL = nilIfBlank(logoURL)
        target.exchangeName = nilIfBlank(exchangeName)
        target.currencyCode = nilIfBlank(currencyCode)
        target.updatedAt = .now

        if isNewHolding {
            modelContext.insert(target)
            modelContext.insert(initialTransaction(for: target))
        }
        try? modelContext.save()
        hydrateMarketDataIfNeeded(for: target)
        dismiss()
    }

    private func initialTransaction(for holding: Holding) -> Transaction {
        Transaction(
            kind: .buy,
            date: holding.purchaseDate,
            quantity: holding.kind.isMarketPriced ? holding.quantity : 0,
            price: initialTransactionPrice(for: holding),
            fees: holding.fees,
            note: "Initial position",
            holding: holding
        )
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

    private func currencyField(_ title: String, value: Binding<Double>) -> some View {
        EmptyZeroNumberField(title: title, value: value, maxFractionDigits: 2)
    }

    private func numberField(_ title: String, value: Binding<Double>) -> some View {
        EmptyZeroNumberField(title: title, value: value, maxFractionDigits: 6)
    }

    private func percentField(_ title: String, value: Binding<Double>) -> some View {
        EmptyZeroNumberField(title: title, value: value, maxFractionDigits: 3)
    }

    @ViewBuilder
    private var marketProfilePreview: some View {
        if isLookingUp || lookupMessage != nil || !sector.isEmpty || !industry.isEmpty || dividendYield != nil {
            VStack(alignment: .leading, spacing: 7) {
                if isLookingUp {
                    Label("Looking up ticker", systemImage: "magnifyingglass")
                        .foregroundStyle(WorthlineTheme.textSecondary)
                } else if let lookupMessage {
                    Label(lookupMessage, systemImage: "info.circle")
                        .foregroundStyle(WorthlineTheme.textSecondary)
                }
                if !sector.isEmpty || !industry.isEmpty || dividendYield != nil {
                    HStack(spacing: 10) {
                        if !sector.isEmpty {
                            profileChip(sector)
                        }
                        if !industry.isEmpty {
                            profileChip(industry)
                        }
                        if let dividendYield {
                            profileChip("Dividend \(dividendYield.formatted(Formatters.percent))")
                        }
                    }
                }
            }
            .font(.caption.weight(.medium))
        }
    }

    private func profileChip(_ text: String) -> some View {
        Text(text)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(WorthlineTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func scheduleTickerLookup(for ticker: String, delay: Duration = .milliseconds(450)) {
        lookupTask?.cancel()
        guard kind.isMarketPriced, !ticker.isEmpty else {
            lookupMessage = nil
            return
        }

        lookupTask = Task {
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            await lookupTicker(ticker)
        }
    }

    @MainActor
    private func lookupTicker(_ ticker: String) async {
        isLookingUp = true
        lookupMessage = nil
        defer { isLookingUp = false }

        do {
            async let quote = quoteService.fetchQuote(for: ticker)
            async let profileResult = quoteService.fetchProfile(for: ticker)
            let fetchedQuote = try await quote
            apply(quote: fetchedQuote)
            do {
                apply(profile: try await profileResult)
                lookupMessage = "Ticker details filled"
            } catch {
                lookupMessage = "Price found; profile details unavailable"
            }
        } catch {
            lookupMessage = error.localizedDescription
        }
    }

    private func apply(quote: QuotePrice) {
        ticker = quote.symbol
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = quote.longName ?? quote.shortName ?? quote.symbol
        }
        exchangeName = quote.exchangeName ?? exchangeName
        currencyCode = quote.currency ?? currencyCode
    }

    private func apply(profile: MarketAssetProfile) {
        ticker = profile.symbol
        name = profile.longName ?? profile.shortName ?? name
        sector = profile.sector ?? sector
        industry = profile.industry ?? industry
        dividendYield = profile.dividendYield ?? dividendYield
        earningsDate = profile.earningsDate ?? earningsDate
        website = profile.website ?? website
        logoURL = profile.logoURL ?? logoURL
        exchangeName = profile.exchangeName ?? exchangeName
        currencyCode = profile.currency ?? currencyCode
    }

    private func hydrateMarketDataIfNeeded(for holding: Holding) {
        guard holding.kind.isMarketPriced, !holding.ticker.isEmpty else { return }

        Task { @MainActor in
            do {
                let quote = try await quoteService.fetchQuote(for: holding.ticker)
                holding.apply(price: quote)
                if let profile = try? await quoteService.fetchProfile(for: holding.ticker) {
                    holding.apply(profile: profile)
                }
                modelContext.insert(PriceSnapshot(price: quote.regularMarketPrice, holding: holding))
                let historyStart = min(holding.purchaseDate, Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? holding.purchaseDate)
                if let history = try? await quoteService.fetchPriceHistory(for: holding.ticker, from: historyStart) {
                    insertMissingSnapshots(history, for: holding)
                }
                try? modelContext.save()
            } catch {
                try? modelContext.save()
            }
        }
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

    private func nilIfBlank(_ text: String) -> String? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}

private struct EmptyZeroNumberField: View {
    let title: String
    @Binding var value: Double
    let maxFractionDigits: Int
    @State private var text = ""

    var body: some View {
        TextField(title, text: $text, prompt: Text(title))
            .aureusFieldStyle()
            .onAppear {
                text = formatted(value)
            }
            .onChange(of: text) { _, newValue in
                let cleaned = newValue
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: "$", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                value = Double(cleaned) ?? 0
            }
    }

    private func formatted(_ value: Double) -> String {
        guard value != 0 else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
