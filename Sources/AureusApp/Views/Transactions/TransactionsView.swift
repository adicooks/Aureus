import SwiftData
import SwiftUI

enum TransactionFilter: String, CaseIterable, Hashable {
    case all = "All"
    case buy = "Buy"
    case sell = "Sell"
    case dividend = "Dividend"
    case deposit = "Deposit"
    case withdrawal = "Withdrawal"

    func includes(_ kind: TransactionKind) -> Bool {
        switch self {
        case .all: true
        case .buy: kind == .buy
        case .sell: kind == .sell
        case .dividend: kind == .dividend
        case .deposit: kind == .deposit
        case .withdrawal: kind == .withdrawal
        }
    }
}

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var searchText = ""
    @State private var filter: TransactionFilter = .all
    @State private var showingEditor = false
    @State private var deleteCandidate: Transaction?

    private var filteredTransactions: [Transaction] {
        var items = transactions.filter { filter.includes($0.kind) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter {
                $0.kind.title.localizedCaseInsensitiveContains(query)
                || ($0.holding?.name.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.holding?.ticker.localizedCaseInsensitiveContains(query) ?? false)
                || $0.note.localizedCaseInsensitiveContains(query)
            }
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            controls

            SectionCard(padding: 0) {
                if transactions.isEmpty {
                    EmptyStateView(
                        title: "No transactions yet",
                        message: "Track buys, sells, dividends, deposits, and withdrawals from one clean ledger.",
                        symbol: "arrow.left.arrow.right",
                        buttonTitle: "Add Transaction",
                        action: { showingEditor = true }
                    )
                    .frame(minHeight: 500)
                } else if filteredTransactions.isEmpty {
                    EmptyStateView(
                        title: "No matching transactions",
                        message: "Adjust your search or filter to widen the ledger.",
                        symbol: "magnifyingglass"
                    )
                    .frame(minHeight: 460)
                } else {
                    TransactionTable(
                        transactions: filteredTransactions,
                        deleteAction: { deleteCandidate = $0 }
                    )
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .premiumPageBackground()
        .sheet(isPresented: $showingEditor) {
            TransactionEditorView()
                .frame(minWidth: 520, minHeight: 520)
        }
        .alert("Delete Transaction?", isPresented: Binding(
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
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
        } message: {
            Text("This removes the transaction from local storage. The holding itself is not deleted.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Transactions")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("\(transactions.count) local records")
                    .font(.callout)
                    .foregroundStyle(WorthlineTheme.textSecondary)
            }
            Spacer()
            PrimaryButton(title: "Add Transaction", symbol: "plus") {
                showingEditor = true
            }
        }
        .padding([.horizontal, .top], 28)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SearchField(placeholder: "Search transactions...", text: $searchText)
                .frame(width: 320)
            FilterPills(options: TransactionFilter.allCases, selection: $filter) { filter in
                Text(filter.rawValue)
            }
        }
        .padding(.horizontal, 28)
    }
}

struct TransactionTable: View {
    let transactions: [Transaction]
    var deleteAction: ((Transaction) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction, deleteAction: deleteAction)
                        Divider().opacity(0.55)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            label("Date", alignment: .leading).frame(width: 104, alignment: .leading)
            label("Type", alignment: .leading).frame(width: 110, alignment: .leading)
            label("Asset", alignment: .leading).frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
            label("Description", alignment: .leading).frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
            label("Quantity").frame(width: 95, alignment: .trailing)
            label("Price").frame(width: 105, alignment: .trailing)
            label("Amount").frame(width: 120, alignment: .trailing)
            if deleteAction != nil {
                Color.clear.frame(width: 26)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.08))
        .frame(height: 36)
    }

    private func label(_ text: String, alignment: Alignment = .trailing) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(WorthlineTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

private struct TransactionRow: View {
    let transaction: Transaction
    let deleteAction: ((Transaction) -> Void)?
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Text(transaction.date.formatted(Formatters.shortDate))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 104, alignment: .leading)
            Label(transaction.kind.title, systemImage: transaction.kind.symbol)
                .foregroundStyle(tint)
                .frame(width: 110, alignment: .leading)
            Text(transaction.holding?.displayTicker ?? "Cash")
                .fontWeight(.semibold)
                .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
            Text(transaction.note.isEmpty ? (transaction.holding?.name ?? transaction.kind.title) : transaction.note)
                .foregroundStyle(WorthlineTheme.textSecondary)
                .lineLimit(1)
                .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
            Text(transaction.quantity == 0 ? "-" : transaction.quantity.formatted(Formatters.number))
                .frame(width: 95, alignment: .trailing)
            Text(transaction.price == 0 ? "-" : transaction.price.formatted(Formatters.currency))
                .frame(width: 105, alignment: .trailing)
            Text(transaction.presentationAmount, format: Formatters.currency)
                .foregroundStyle(transaction.presentationIsPositive ? WorthlineTheme.positive : WorthlineTheme.negative)
                .fontWeight(.semibold)
                .frame(width: 120, alignment: .trailing)
            if let deleteAction {
                Menu {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deleteAction(transaction)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 26)
            }
        }
        .font(.callout)
        .monospacedDigit()
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(hovering ? WorthlineTheme.accent.opacity(0.08) : Color.clear)
        .onHover { hovering = $0 }
    }

    private var tint: Color {
        transaction.presentationIsPositive ? WorthlineTheme.positive : WorthlineTheme.negative
    }
}

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Holding.name) private var holdings: [Holding]

    @State private var kind: TransactionKind = .buy
    @State private var selectedHoldingID: UUID?
    @State private var date: Date = .now
    @State private var quantity: Double = 0
    @State private var price: Double = 0
    @State private var fees: Double = 0
    @State private var note: String = ""
    @State private var validationMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case quantity
        case note
    }

    init(preselectedHolding: Holding? = nil) {
        _selectedHoldingID = State(initialValue: preselectedHolding?.id)
        _price = State(initialValue: preselectedHolding?.latestPrice ?? preselectedHolding?.purchasePrice ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Picker("Type", selection: $kind) {
                                ForEach(TransactionKind.allCases) { kind in
                                    Label(kind.title, systemImage: kind.symbol).tag(kind)
                                }
                            }
                            .controlSize(.large)
                            Picker("Asset", selection: $selectedHoldingID) {
                                Text("Cash / Unassigned").tag(UUID?.none)
                                ForEach(holdings) { holding in
                                    Text("\(holding.displayTicker) · \(holding.name)").tag(Optional(holding.id))
                                }
                            }
                            .controlSize(.large)
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                                .controlSize(.large)
                        }
                    }

                    SectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField("Quantity", value: $quantity, format: .number.precision(.fractionLength(0...6)))
                                .aureusFieldStyle()
                                .focused($focusedField, equals: .quantity)
                            TextField(kind == .deposit || kind == .withdrawal ? "Amount" : "Price", value: $price, format: .number.precision(.fractionLength(0...2)))
                                .aureusFieldStyle()
                            TextField("Fees", value: $fees, format: .number.precision(.fractionLength(0...2)))
                                .aureusFieldStyle()
                            TextField("Description", text: $note)
                                .aureusFieldStyle()
                                .focused($focusedField, equals: .note)
                        }
                    }

                    SectionCard {
                        HStack {
                            Text("Signed Amount")
                                .foregroundStyle(WorthlineTheme.textSecondary)
                            Spacer()
                            Text(presentationAmount, format: Formatters.currency)
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(presentationIsPositive ? WorthlineTheme.positive : WorthlineTheme.negative)
                        }
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .foregroundStyle(WorthlineTheme.negative)
                            .font(.callout)
                    }
                }
                .padding(22)
            }
            .premiumPageBackground()
            .navigationTitle("Add Transaction")
            .onAppear { focusedField = .quantity }
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

    private var selectedHolding: Holding? {
        guard let selectedHoldingID else { return nil }
        return holdings.first { $0.id == selectedHoldingID }
    }

    private var signedAmount: Double {
        let gross = quantity == 0 ? price : quantity * price
        switch kind {
        case .buy, .withdrawal:
            return -(gross + fees)
        case .sell:
            return gross - fees
        case .dividend, .deposit, .interest, .adjustment:
            return gross - fees
        }
    }

    private var presentationIsPositive: Bool {
        switch kind {
        case .buy, .deposit, .dividend, .interest:
            return true
        case .sell, .withdrawal:
            return false
        case .adjustment:
            return signedAmount >= 0
        }
    }

    private var presentationAmount: Double {
        presentationIsPositive ? abs(signedAmount) : -abs(signedAmount)
    }

    private func save() {
        guard price >= 0, quantity >= 0, fees >= 0 else {
            validationMessage = "Values cannot be negative."
            return
        }
        guard price > 0 || quantity > 0 else {
            validationMessage = "Enter an amount or quantity before saving."
            return
        }

        let transaction = Transaction(
            kind: kind,
            date: date,
            quantity: quantity,
            price: price,
            fees: fees,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            holding: selectedHolding
        )
        applyTransactionToSelectedHolding()
        modelContext.insert(transaction)
        try? modelContext.save()
        dismiss()
    }

    private func applyTransactionToSelectedHolding() {
        guard let selectedHolding else { return }
        let gross = quantity == 0 ? price : quantity * price
        let transactionQuantity = quantity

        switch kind {
        case .buy:
            if selectedHolding.kind.isMarketPriced, transactionQuantity > 0 {
                let currentQuantity = selectedHolding.quantity
                let currentCost = currentQuantity * selectedHolding.purchasePrice
                let newQuantity = currentQuantity + transactionQuantity
                selectedHolding.quantity = newQuantity
                selectedHolding.purchasePrice = newQuantity > 0 ? (currentCost + transactionQuantity * price) / newQuantity : price
                selectedHolding.fees += fees
                selectedHolding.latestPrice = selectedHolding.latestPrice ?? price
                selectedHolding.previousClose = selectedHolding.previousClose ?? price
            } else if !selectedHolding.kind.isMarketPriced {
                selectedHolding.manualCurrentValue += gross
                selectedHolding.purchasePrice += gross
                selectedHolding.fees += fees
            }
            if date < selectedHolding.purchaseDate {
                selectedHolding.purchaseDate = date
            }
        case .sell:
            if selectedHolding.kind.isMarketPriced, transactionQuantity > 0 {
                selectedHolding.quantity = max(0, selectedHolding.quantity - transactionQuantity)
            } else if !selectedHolding.kind.isMarketPriced {
                selectedHolding.manualCurrentValue = max(0, selectedHolding.manualCurrentValue - gross)
            }
        case .deposit:
            guard !selectedHolding.kind.isMarketPriced else { break }
            selectedHolding.manualCurrentValue += gross
            selectedHolding.purchasePrice += gross
        case .withdrawal:
            guard !selectedHolding.kind.isMarketPriced else { break }
            selectedHolding.manualCurrentValue = max(0, selectedHolding.manualCurrentValue - gross)
        case .dividend, .interest, .adjustment:
            break
        }

        selectedHolding.updatedAt = .now
    }
}
