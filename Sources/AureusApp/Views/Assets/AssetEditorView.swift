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
    @State private var validationMessage: String?

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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var details: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Details")
                TextField("Name", text: $name)
                if kind.isMarketPriced {
                    TextField("Ticker", text: $ticker)
                        .onChange(of: ticker) { _, newValue in
                            ticker = newValue.uppercased()
                        }
                }
                if kind == .custom || kind == .collectible || kind == .business || kind == .realEstate {
                    TextField("Category", text: $customCategory)
                }
                DatePicker(kind == .bond ? "Purchase Date" : "Date Added", selection: $purchaseDate, displayedComponents: .date)
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
                    currencyField("Current Value", value: $manualCurrentValue)
                }
            }
        } else if kind.isMarketPriced {
            SectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Position")
                    numberField("Quantity", value: $quantity)
                    currencyField("Purchase Price", value: $purchasePrice)
                    currencyField("Fees", value: $fees)
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

        let target = holding ?? Holding(kind: kind, name: cleanName)
        target.kind = kind
        target.name = cleanName
        target.ticker = cleanTicker
        target.quantity = quantity
        target.purchaseDate = purchaseDate
        target.purchasePrice = purchasePrice
        target.fees = fees
        target.notes = notes
        target.principalAmount = principalAmount
        target.interestRate = interestRate
        target.maturityDate = kind == .bond ? maturityDate : nil
        target.customCategory = customCategory
        target.manualCurrentValue = manualCurrentValue
        target.updatedAt = .now

        if holding == nil {
            modelContext.insert(target)
        }
        try? modelContext.save()
        dismiss()
    }

    private func currencyField(_ title: String, value: Binding<Double>) -> some View {
        TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
    }

    private func numberField(_ title: String, value: Binding<Double>) -> some View {
        TextField(title, value: value, format: .number.precision(.fractionLength(0...6)))
    }

    private func percentField(_ title: String, value: Binding<Double>) -> some View {
        TextField(title, value: value, format: .number.precision(.fractionLength(0...3)))
    }
}

