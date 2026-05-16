import Foundation

struct NetWorthHistoryPoint: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let totalValue: Double
    let investedAmount: Double
    let unrealizedGainLoss: Double
}

enum PortfolioHistoryService {
    static func series(
        holdings: [Holding],
        snapshots: [NetWorthSnapshot],
        range: TimeRange,
        transactions: [Transaction] = [],
        now: Date = .now
    ) -> [NetWorthHistoryPoint] {
        let snapshotSeries = snapshots
            .filter { range.contains($0.date, relativeTo: now) }
            .sorted { $0.date < $1.date }
            .map {
                NetWorthHistoryPoint(
                    date: $0.date,
                    totalValue: $0.totalValue,
                    investedAmount: $0.investedAmount,
                    unrealizedGainLoss: $0.unrealizedGainLoss
                )
            }

        if range != .oneDay, hasMultipleSnapshotDays(snapshotSeries) {
            return snapshotSeries
        }

        let synthesized = synthesizedSeries(holdings: holdings, range: range, transactions: transactions, now: now)
        if synthesized.count > 1 {
            return synthesized
        }

        return snapshotSeries.isEmpty ? synthesized : snapshotSeries
    }

    private static func hasMultipleSnapshotDays(_ series: [NetWorthHistoryPoint], calendar: Calendar = .current) -> Bool {
        guard let firstDate = series.first?.date else { return false }
        let firstDay = calendar.startOfDay(for: firstDate)
        return series.contains { calendar.startOfDay(for: $0.date) != firstDay }
    }

    private static func synthesizedSeries(
        holdings: [Holding],
        range: TimeRange,
        transactions: [Transaction],
        now: Date
    ) -> [NetWorthHistoryPoint] {
        let activeHoldings = holdings.filter { !$0.isArchived || !transactionsForHolding($0, in: transactions).isEmpty }
        guard !activeHoldings.isEmpty else { return [] }

        let calendar = Calendar.current
        let dates = timelineDates(for: activeHoldings, transactions: transactions, range: range, now: now, calendar: calendar)
        let holdingsWithSnapshots = activeHoldings.map { holding in
            (holding: holding, snapshots: holding.priceSnapshots.sorted { $0.date < $1.date })
        }
        var cursors = holdingsWithSnapshots.map {
            HoldingHistoryCursor(
                holding: $0.holding,
                snapshots: $0.snapshots,
                transactions: transactionsForHolding($0.holding, in: transactions)
            )
        }

        return dates
            .map { date in
                let values = cursors.indices.map { index in
                    cursors[index].value(at: date, range: range, now: now, calendar: calendar)
                }
                let total = values.reduce(0) { $0 + $1.currentValue }
                let invested = values.reduce(0) { $0 + $1.costBasis }
                return NetWorthHistoryPoint(
                    date: date,
                    totalValue: total,
                    investedAmount: invested,
                    unrealizedGainLoss: total - invested
                )
            }
            .filter { $0.totalValue > 0 || $0.investedAmount > 0 }
    }

    private static func timelineDates(for holdings: [Holding], transactions: [Transaction], range: TimeRange, now: Date, calendar: Calendar) -> [Date] {
        let earliestDate = holdings.reduce(Date?.none) { current, holding in
            let earliestSnapshot = holding.priceSnapshots.reduce(Date?.none) { snapshotDate, snapshot in
                guard let snapshotDate else { return snapshot.date }
                return min(snapshotDate, snapshot.date)
            }
            let earliestTransaction = transactionsForHolding(holding, in: transactions)
                .map(\.date)
                .min()
            let holdingEarliest = [holding.purchaseDate, earliestSnapshot, earliestTransaction].compactMap { $0 }.min()
            guard let holdingEarliest else { return current }
            guard let current else { return holdingEarliest }
            return min(current, holdingEarliest)
        }

        let start = range.startDate(relativeTo: now, calendar: calendar) ?? earliestDate ?? now
        var dates: [Date] = [start]
        dates.append(contentsOf: eventDates(for: holdings, transactions: transactions, range: range, now: now))
        let step = timelineStep(for: range)
        var cursor = start
        var guardCount = 0

        while cursor < now && guardCount < 420 {
            guard let next = calendar.date(byAdding: step.component, value: step.value, to: cursor), next > cursor else {
                break
            }
            if next < now {
                dates.append(next)
            }
            cursor = next
            guardCount += 1
        }

        dates.append(now)
        return Array(Set(dates.filter { $0 <= now && range.contains($0, relativeTo: now) })).sorted()
    }

    private static func eventDates(for holdings: [Holding], transactions: [Transaction], range: TimeRange, now: Date) -> [Date] {
        holdings.flatMap { holding in
            [holding.purchaseDate]
                + holding.priceSnapshots.map(\.date)
                + transactionsForHolding(holding, in: transactions).map(\.date)
        }
        .filter { $0 <= now && range.contains($0, relativeTo: now) }
    }

    private static func transactionsForHolding(_ holding: Holding, in transactions: [Transaction]) -> [Transaction] {
        let matchingTransactions = transactions.filter { $0.holding?.id == holding.id }
        let source = matchingTransactions.isEmpty ? holding.transactions : matchingTransactions
        return source.sorted { $0.date < $1.date }
    }

    private static func timelineStep(for range: TimeRange) -> (component: Calendar.Component, value: Int) {
        switch range {
        case .oneDay:
            return (.day, 1)
        case .oneWeek, .oneMonth, .threeMonths:
            return (.day, 1)
        case .oneYear:
            return (.weekOfYear, 1)
        case .all:
            return (.month, 1)
        }
    }
}

private struct HoldingHistoryCursor {
    let holding: Holding
    let snapshots: [PriceSnapshot]
    let transactions: [Transaction]
    private var snapshotIndex = 0
    private var transactionIndex = 0
    private var latestSnapshotPrice: Double?
    private var latestTransactionPrice: Double?
    private var transactionQuantity = 0.0
    private var transactionCostBasis = 0.0
    private var manualTransactionValue = 0.0

    init(holding: Holding, snapshots: [PriceSnapshot], transactions: [Transaction]) {
        self.holding = holding
        self.snapshots = snapshots
        self.transactions = transactions
    }

    mutating func value(
        at date: Date,
        range: TimeRange,
        now: Date,
        calendar: Calendar
    ) -> (currentValue: Double, costBasis: Double) {
        guard date >= earliestActivityDate else { return (0, 0) }

        while snapshotIndex < snapshots.count, snapshots[snapshotIndex].date <= date {
            latestSnapshotPrice = snapshots[snapshotIndex].price
            snapshotIndex += 1
        }

        while transactionIndex < transactions.count, transactions[transactionIndex].date <= date {
            apply(transactions[transactionIndex])
            transactionIndex += 1
        }

        if !transactions.isEmpty {
            return transactionBackedValue(at: date, range: range, now: now, calendar: calendar)
        }

        switch holding.kind {
        case .stock, .etf, .crypto, .commodity:
            let price = marketPrice(at: date, range: range, now: now, calendar: calendar)
            return (max(0, holding.quantity * price), holding.costBasis)
        case .bond, .cash, .realEstate, .business, .collectible, .custom:
            return (holding.currentValue, holding.costBasis)
        }
    }

    private mutating func apply(_ transaction: Transaction) {
        let grossAmount = transaction.grossAmount
        if transaction.price > 0 {
            latestTransactionPrice = transaction.price
        }

        switch transaction.kind {
        case .buy:
            if holding.kind.isMarketPriced {
                transactionQuantity += transaction.quantity
                transactionCostBasis += transaction.quantity * transaction.price + transaction.fees
            } else {
                manualTransactionValue += grossAmount
                transactionCostBasis += grossAmount + transaction.fees
            }
        case .sell:
            if holding.kind.isMarketPriced {
                let soldQuantity = min(transaction.quantity, transactionQuantity)
                if transactionQuantity > 0 {
                    let averageCost = transactionCostBasis / transactionQuantity
                    transactionCostBasis = max(0, transactionCostBasis - averageCost * soldQuantity)
                }
                transactionQuantity = max(0, transactionQuantity - soldQuantity)
            } else {
                manualTransactionValue = max(0, manualTransactionValue - grossAmount)
                transactionCostBasis = min(transactionCostBasis, manualTransactionValue)
            }
        case .deposit, .interest, .adjustment:
            guard !holding.kind.isMarketPriced else { return }
            manualTransactionValue += grossAmount
            transactionCostBasis += grossAmount
        case .withdrawal:
            guard !holding.kind.isMarketPriced else { return }
            manualTransactionValue = max(0, manualTransactionValue - grossAmount)
            transactionCostBasis = min(transactionCostBasis, manualTransactionValue)
        case .dividend:
            break
        }
    }

    private func transactionBackedValue(
        at date: Date,
        range: TimeRange,
        now: Date,
        calendar: Calendar
    ) -> (currentValue: Double, costBasis: Double) {
        guard transactionQuantity > 0 || manualTransactionValue > 0 || transactionCostBasis > 0 else {
            return (0, 0)
        }

        switch holding.kind {
        case .stock, .etf, .crypto, .commodity:
            let price = marketPrice(at: date, range: range, now: now, calendar: calendar)
            return (max(0, transactionQuantity * price), max(0, transactionCostBasis))
        case .bond, .cash, .realEstate, .business, .collectible, .custom:
            if calendar.isDate(date, inSameDayAs: now) {
                return (holding.currentValue, holding.costBasis)
            }
            return (max(0, manualTransactionValue), max(0, transactionCostBasis))
        }
    }

    private func marketPrice(at date: Date, range: TimeRange, now: Date, calendar: Calendar) -> Double {
        if range == .oneDay,
           let dayStart = range.startDate(relativeTo: now, calendar: calendar),
           abs(date.timeIntervalSince(dayStart)) < 1 {
            return holding.previousClose ?? holding.latestPrice ?? latestTransactionPrice ?? holding.purchasePrice
        }

        if calendar.isDate(date, inSameDayAs: now), let latestPrice = holding.latestPrice {
            return latestPrice
        }

        return latestSnapshotPrice ?? latestTransactionPrice ?? holding.purchasePrice
    }

    private var earliestActivityDate: Date {
        guard let firstTransactionDate = transactions.first?.date else { return holding.purchaseDate }
        return min(holding.purchaseDate, firstTransactionDate)
    }
}
