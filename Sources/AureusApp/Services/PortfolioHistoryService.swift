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

        let calendar = Calendar.current
        var dates = Set<Date>()
        dates.insert(now)
        let holdingsWithSnapshots = activeHoldings.map { holding in
            (holding: holding, snapshots: holding.priceSnapshots.sorted { $0.date < $1.date })
        }
        for holding in activeHoldings {
            dates.insert(bucketedDate(holding.purchaseDate, calendar: calendar, range: range, now: now))
            holding.priceSnapshots.forEach {
                dates.insert(bucketedDate($0.date, calendar: calendar, range: range, now: now))
            }
        }

        return dates
            .filter { $0 <= now && range.contains($0, relativeTo: now) }
            .sorted()
            .map { date in
                let values = holdingsWithSnapshots.map { value(for: $0.holding, snapshots: $0.snapshots, at: date, now: now) }
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

    private static func value(
        for holding: Holding,
        snapshots: [PriceSnapshot],
        at date: Date,
        now: Date
    ) -> (currentValue: Double, costBasis: Double) {
        guard date >= holding.purchaseDate else { return (0, 0) }

        switch holding.kind {
        case .stock, .etf, .crypto:
            let price = marketPrice(for: holding, snapshots: snapshots, at: date, now: now)
            return (max(0, holding.quantity * price), holding.costBasis)
        case .bond, .cash, .realEstate, .business, .collectible, .custom:
            return (holding.currentValue, holding.costBasis)
        }
    }

    private static func marketPrice(for holding: Holding, snapshots: [PriceSnapshot], at date: Date, now: Date) -> Double {
        if Calendar.current.isDate(date, inSameDayAs: now), let latestPrice = holding.latestPrice {
            return latestPrice
        }

        let priorSnapshot = snapshots.last { $0.date <= date }
        return priorSnapshot?.price ?? holding.purchasePrice
    }

    private static func bucketedDate(_ date: Date, calendar: Calendar, range: TimeRange, now: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        return range.contains(day, relativeTo: now) ? day : date
    }
}
