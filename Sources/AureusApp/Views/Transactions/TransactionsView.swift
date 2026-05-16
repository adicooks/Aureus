import SwiftData
import SwiftUI

enum TransactionFilter: String, CaseIterable, Hashable {
    case all = "All"
    case buy = "Buy"
    case sell = "Sell"

    func includes(_ kind: TransactionKind) -> Bool {
        switch self {
        case .all: true
        case .buy: kind == .buy
        case .sell: kind == .sell
        }
    }
}

private struct CompletedStockTrade: Identifiable {
    let holding: Holding
    let buys: [Transaction]
    let sells: [Transaction]

    var id: UUID { holding.id }
    var date: Date { sells.map(\.date).max() ?? buys.map(\.date).max() ?? holding.updatedAt }
    var buyQuantity: Double { buys.reduce(0) { $0 + $1.quantity } }
    var sellQuantity: Double { sells.reduce(0) { $0 + $1.quantity } }
    var boughtAmount: Double { buys.reduce(0) { $0 + $1.grossAmount + $1.fees } }
    var soldAmount: Double { sells.reduce(0) { $0 + $1.grossAmount - $1.fees } }
    var averageBuyPrice: Double { buyQuantity > 0 ? boughtAmount / buyQuantity : 0 }
    var averageSellPrice: Double { sellQuantity > 0 ? soldAmount / sellQuantity : 0 }
    var realizedAmount: Double { soldAmount - averageBuyPrice * sellQuantity }
    var isGain: Bool { realizedAmount >= 0 }

    var description: String {
        "Bought \(buyQuantity.formatted(Formatters.number)) @ \(averageBuyPrice.formatted(Formatters.currency)); sold \(sellQuantity.formatted(Formatters.number)) @ \(averageSellPrice.formatted(Formatters.currency))"
    }
}

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var searchText = ""
    @State private var filter: TransactionFilter = .all
    @State private var showingEditor = false
    @State private var deleteCandidate: Transaction?

    private var stockTransactions: [Transaction] {
        transactions.filter { transaction in
            (transaction.kind == .buy || transaction.kind == .sell)
            && transaction.holding?.kind == .stock
        }
    }

    private var completedStockTrades: [CompletedStockTrade] {
        let grouped = Dictionary(grouping: stockTransactions) { $0.holding?.id }
        return grouped.compactMap { _, transactions in
            let buys = transactions.filter { $0.kind == .buy }.sorted { $0.date > $1.date }
            let sells = transactions.filter { $0.kind == .sell }.sorted { $0.date > $1.date }
            guard let holding = transactions.compactMap(\.holding).first, !buys.isEmpty, !sells.isEmpty else {
                return nil
            }
            return CompletedStockTrade(holding: holding, buys: buys, sells: sells)
        }
        .sorted { $0.date > $1.date }
    }

    private var filteredTransactions: [Transaction] {
        var items = stockTransactions.filter { filter.includes($0.kind) }
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

    private var filteredCompletedStockTrades: [CompletedStockTrade] {
        var items = completedStockTrades
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter {
                $0.holding.name.localizedCaseInsensitiveContains(query)
                || $0.holding.ticker.localizedCaseInsensitiveContains(query)
                || $0.description.localizedCaseInsensitiveContains(query)
            }
        }
        return items
    }

    private var visibleRecordCount: Int {
        switch filter {
        case .all: filteredCompletedStockTrades.count
        case .buy, .sell: filteredTransactions.count
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            controls

            SectionCard(padding: 0) {
                if stockTransactions.isEmpty {
                    EmptyStateView(
                        title: "No transactions yet",
                        message: "Track stock buys and sells from one clean ledger.",
                        symbol: "arrow.left.arrow.right",
                        buttonTitle: "Add Transaction",
                        action: { showingEditor = true }
                    )
                    .frame(minHeight: 500)
                } else if visibleRecordCount == 0 {
                    EmptyStateView(
                        title: "No matching transactions",
                        message: filter == .all ? "All shows stocks with both a buy and sell record." : "Adjust your search or filter to widen the ledger.",
                        symbol: "magnifyingglass"
                    )
                    .frame(minHeight: 460)
                } else if filter == .all {
                    CompletedStockTradeTable(trades: filteredCompletedStockTrades)
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
                Text("\(visibleRecordCount) stock records")
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

private struct CompletedStockTradeTable: View {
    let trades: [CompletedStockTrade]

    private var totalSellQuantity: Double {
        trades.reduce(0) { $0 + $1.sellQuantity }
    }

    private var totalSoldAmount: Double {
        trades.reduce(0) { $0 + $1.soldAmount }
    }

    private var averageSellPrice: Double {
        totalSellQuantity > 0 ? totalSoldAmount / totalSellQuantity : 0
    }

    private var totalRealizedAmount: Double {
        trades.reduce(0) { $0 + $1.realizedAmount }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(trades) { trade in
                        CompletedStockTradeRow(trade: trade)
                        Divider().opacity(0.55)
                    }
                }
            }
            totalRow
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
            label("Gain/Loss").frame(width: 120, alignment: .trailing)
            Color.clear.frame(width: 26)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.08))
        .frame(height: 36)
    }

    private var totalRow: some View {
        HStack(spacing: 12) {
            Text("Total")
                .font(.callout.weight(.bold))
                .frame(width: 104, alignment: .leading)
            Color.clear.frame(width: 110)
            Color.clear.frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
            Text("\(trades.count) completed trades")
                .font(.callout.weight(.semibold))
                .foregroundStyle(WorthlineTheme.textSecondary)
                .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
            Text(totalSellQuantity.formatted(Formatters.number))
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .frame(width: 95, alignment: .trailing)
            Text(averageSellPrice == 0 ? "-" : averageSellPrice.formatted(Formatters.currency))
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .frame(width: 105, alignment: .trailing)
            Text(totalRealizedAmount, format: Formatters.currency)
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(totalRealizedAmount >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
                .frame(width: 120, alignment: .trailing)
            Color.clear.frame(width: 26)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
        .frame(height: 54)
    }

    private func label(_ text: String, alignment: Alignment = .trailing) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(WorthlineTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

private struct CompletedStockTradeRow: View {
    let trade: CompletedStockTrade
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Text(trade.date.formatted(Formatters.shortDate))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 104, alignment: .leading)
            Label("Bought & Sold", systemImage: "arrow.left.arrow.right.circle")
                .foregroundStyle(trade.isGain ? WorthlineTheme.positive : WorthlineTheme.negative)
                .frame(width: 110, alignment: .leading)
            Text(trade.holding.displayTicker)
                .fontWeight(.semibold)
                .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
            Text(trade.description)
                .foregroundStyle(WorthlineTheme.textSecondary)
                .lineLimit(1)
                .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
            Text(trade.sellQuantity.formatted(Formatters.number))
                .frame(width: 95, alignment: .trailing)
            Text(trade.averageSellPrice == 0 ? "-" : trade.averageSellPrice.formatted(Formatters.currency))
                .frame(width: 105, alignment: .trailing)
            Text(trade.realizedAmount, format: Formatters.currency)
                .foregroundStyle(trade.isGain ? WorthlineTheme.positive : WorthlineTheme.negative)
                .fontWeight(.semibold)
                .frame(width: 120, alignment: .trailing)
            Color.clear.frame(width: 26)
        }
        .font(.callout)
        .monospacedDigit()
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(hovering ? WorthlineTheme.accent.opacity(0.08) : Color.clear)
        .onHover { hovering = $0 }
    }
}

struct TransactionTable: View {
    let transactions: [Transaction]
    var deleteAction: ((Transaction) -> Void)?

    private var totalQuantity: Double {
        transactions.reduce(0) { $0 + $1.quantity }
    }

    private var totalGrossAmount: Double {
        transactions.reduce(0) { $0 + $1.grossAmount }
    }

    private var averagePrice: Double {
        totalQuantity > 0 ? totalGrossAmount / totalQuantity : 0
    }

    private var totalPresentationAmount: Double {
        transactions.reduce(0) { $0 + $1.presentationAmount }
    }

    private var totalIsPositive: Bool {
        totalPresentationAmount >= 0
    }

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
            totalRow
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

    private var totalRow: some View {
        HStack(spacing: 12) {
            Text("Total")
                .font(.callout.weight(.bold))
                .frame(width: 104, alignment: .leading)
            Color.clear.frame(width: 110)
            Color.clear.frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
            Text("\(transactions.count) transactions")
                .font(.callout.weight(.semibold))
                .foregroundStyle(WorthlineTheme.textSecondary)
                .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
            Text(totalQuantity == 0 ? "-" : totalQuantity.formatted(Formatters.number))
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .frame(width: 95, alignment: .trailing)
            Text(averagePrice == 0 ? "-" : averagePrice.formatted(Formatters.currency))
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .frame(width: 105, alignment: .trailing)
            Text(totalPresentationAmount, format: Formatters.currency)
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(totalIsPositive ? WorthlineTheme.positive : WorthlineTheme.negative)
                .frame(width: 120, alignment: .trailing)
            if deleteAction != nil {
                Color.clear.frame(width: 26)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
        .frame(height: 54)
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

    private let transactionKinds: [TransactionKind] = [.buy, .sell]

    private enum Field: Hashable {
        case quantity
        case note
    }

    init(preselectedHolding: Holding? = nil, initialKind: TransactionKind = .buy) {
        _kind = State(initialValue: initialKind)
        _selectedHoldingID = State(initialValue: preselectedHolding?.id)
        _price = State(initialValue: preselectedHolding?.latestPrice ?? preselectedHolding?.purchasePrice ?? 0)
        _quantity = State(initialValue: initialKind == .sell ? preselectedHolding?.quantity ?? 0 : 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Picker("Type", selection: $kind) {
                                ForEach(transactionKinds) { kind in
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
                            TextField("Price", value: $price, format: .number.precision(.fractionLength(0...2)))
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
                selectedHolding.isArchived = selectedHolding.quantity == 0
            } else if !selectedHolding.kind.isMarketPriced {
                selectedHolding.manualCurrentValue = max(0, selectedHolding.manualCurrentValue - gross)
                selectedHolding.isArchived = selectedHolding.manualCurrentValue == 0
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
