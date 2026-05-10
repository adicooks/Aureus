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
        now: Date = .now
    ) -> [NetWorthHistoryPoint] {
        let synthesized = synthesizedSeries(holdings: holdings, range: range, now: now)
        if synthesized.count > 1 {
            return synthesized
        }

        return snapshots
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
    }

    private static func synthesizedSeries(
        holdings: [Holding],
        range: TimeRange,
        now: Date
    ) -> [NetWorthHistoryPoint] {
        let activeHoldings = holdings.filter { !$0.isArchived }
        guard !activeHoldings.isEmpty else { return [] }

        var dates = Set<Date>()
        dates.insert(now)
        for holding in activeHoldings {
            dates.insert(holding.purchaseDate)
            holding.priceSnapshots.forEach { dates.insert($0.date) }
        }

        return dates
            .filter { $0 <= now && range.contains($0, relativeTo: now) }
            .sorted()
            .map { date in
                let values = activeHoldings.map { value(for: $0, at: date, now: now) }
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

    private static func value(for holding: Holding, at date: Date, now: Date) -> (currentValue: Double, costBasis: Double) {
        guard date >= holding.purchaseDate else { return (0, 0) }

        switch holding.kind {
        case .stock, .etf, .crypto:
            let price = marketPrice(for: holding, at: date, now: now)
            return (max(0, holding.quantity * price), holding.costBasis)
        case .bond, .cash, .realEstate, .business, .collectible, .custom:
            return (holding.currentValue, holding.costBasis)
        }
    }

    private static func marketPrice(for holding: Holding, at date: Date, now: Date) -> Double {
        if Calendar.current.isDate(date, inSameDayAs: now), let latestPrice = holding.latestPrice {
            return latestPrice
        }

        let priorSnapshot = holding.priceSnapshots
            .filter { $0.date <= date }
            .max { $0.date < $1.date }
        return priorSnapshot?.price ?? holding.purchasePrice
    }
}
