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

        if range != .oneDay, snapshotSeries.count > 1 {
            return snapshotSeries
        }

        let synthesized = synthesizedSeries(holdings: holdings, range: range, now: now)
        if synthesized.count > 1 {
            return synthesized
        }

        return snapshotSeries.isEmpty ? synthesized : snapshotSeries
    }

    private static func synthesizedSeries(
        holdings: [Holding],
        range: TimeRange,
        now: Date
    ) -> [NetWorthHistoryPoint] {
        let activeHoldings = holdings.filter { !$0.isArchived }
        guard !activeHoldings.isEmpty else { return [] }

        let calendar = Calendar.current
        let dates = timelineDates(for: activeHoldings, range: range, now: now, calendar: calendar)
        let holdingsWithSnapshots = activeHoldings.map { holding in
            (holding: holding, snapshots: holding.priceSnapshots.sorted { $0.date < $1.date })
        }
        var cursors = holdingsWithSnapshots.map { HoldingHistoryCursor(holding: $0.holding, snapshots: $0.snapshots) }

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

    private static func timelineDates(for holdings: [Holding], range: TimeRange, now: Date, calendar: Calendar) -> [Date] {
        let earliestDate = holdings.reduce(Date?.none) { current, holding in
            let earliestSnapshot = holding.priceSnapshots.reduce(Date?.none) { snapshotDate, snapshot in
                guard let snapshotDate else { return snapshot.date }
                return min(snapshotDate, snapshot.date)
            }
            let holdingEarliest = [holding.purchaseDate, earliestSnapshot].compactMap { $0 }.min()
            guard let holdingEarliest else { return current }
            guard let current else { return holdingEarliest }
            return min(current, holdingEarliest)
        }

        let start = range.startDate(relativeTo: now, calendar: calendar) ?? earliestDate ?? now
        var dates: [Date] = [start]
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
    private var snapshotIndex = 0
    private var latestSnapshotPrice: Double?

    init(holding: Holding, snapshots: [PriceSnapshot]) {
        self.holding = holding
        self.snapshots = snapshots
    }

    mutating func value(
        at date: Date,
        range: TimeRange,
        now: Date,
        calendar: Calendar
    ) -> (currentValue: Double, costBasis: Double) {
        guard date >= holding.purchaseDate else { return (0, 0) }

        while snapshotIndex < snapshots.count, snapshots[snapshotIndex].date <= date {
            latestSnapshotPrice = snapshots[snapshotIndex].price
            snapshotIndex += 1
        }

        switch holding.kind {
        case .stock, .etf, .crypto, .commodity:
            let price = marketPrice(at: date, range: range, now: now, calendar: calendar)
            return (max(0, holding.quantity * price), holding.costBasis)
        case .bond, .cash, .realEstate, .business, .collectible, .custom:
            return (holding.currentValue, holding.costBasis)
        }
    }

    private func marketPrice(at date: Date, range: TimeRange, now: Date, calendar: Calendar) -> Double {
        if range == .oneDay,
           let dayStart = range.startDate(relativeTo: now, calendar: calendar),
           abs(date.timeIntervalSince(dayStart)) < 1 {
            return holding.previousClose ?? holding.latestPrice ?? holding.purchasePrice
        }

        if calendar.isDate(date, inSameDayAs: now), let latestPrice = holding.latestPrice {
            return latestPrice
        }

        return latestSnapshotPrice ?? holding.purchasePrice
    }
}
