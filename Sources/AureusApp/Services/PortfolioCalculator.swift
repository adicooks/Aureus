import Foundation

struct HoldingMetrics: Identifiable {
    var id: UUID { holding.id }
    let holding: Holding
    let currentValue: Double
    let costBasis: Double
    let gainLoss: Double
    let gainLossPercent: Double
    let allocation: Double
}

struct AllocationSlice: Identifiable {
    var id: AssetKind { kind }
    let kind: AssetKind
    let value: Double
    let percent: Double
}

struct PortfolioSummary {
    let totalNetWorth: Double
    let totalInvested: Double
    let unrealizedGainLoss: Double
    let unrealizedGainLossPercent: Double
    let dailyChange: Double?
    let dailyChangePercent: Double?
    let allocation: [AllocationSlice]
    let metrics: [HoldingMetrics]
    let topGainers: [HoldingMetrics]
    let topLosers: [HoldingMetrics]
}

enum PortfolioCalculator {
    static func summarize(_ holdings: [Holding]) -> PortfolioSummary {
        let active = holdings.filter { !$0.isArchived }
        let total = active.reduce(0) { $0 + $1.currentValue }
        let invested = active.reduce(0) { $0 + $1.costBasis }
        let gainLoss = total - invested
        let dailyValues = active.compactMap(\.dailyChange)
        let dailyChange = dailyValues.isEmpty ? nil : dailyValues.reduce(0, +)
        let previousTotal = active.compactMap(\.previousValue).reduce(0, +)
        let metrics = active
            .map { holding in
                HoldingMetrics(
                    holding: holding,
                    currentValue: holding.currentValue,
                    costBasis: holding.costBasis,
                    gainLoss: holding.gainLoss,
                    gainLossPercent: holding.gainLossPercent,
                    allocation: total > 0 ? holding.currentValue / total : 0
                )
            }
            .sorted { $0.currentValue > $1.currentValue }

        let allocation = Dictionary(grouping: active, by: \.kind)
            .map { kind, holdings in
                let value = holdings.reduce(0) { $0 + $1.currentValue }
                return AllocationSlice(kind: kind, value: value, percent: total > 0 ? value / total : 0)
            }
            .sorted { $0.value > $1.value }

        return PortfolioSummary(
            totalNetWorth: total,
            totalInvested: invested,
            unrealizedGainLoss: gainLoss,
            unrealizedGainLossPercent: invested > 0 ? gainLoss / invested : 0,
            dailyChange: dailyChange,
            dailyChangePercent: previousTotal > 0 ? dailyChange.map { $0 / previousTotal } : nil,
            allocation: allocation,
            metrics: metrics,
            topGainers: metrics.filter { $0.gainLoss > 0 }.sorted { $0.gainLossPercent > $1.gainLossPercent }.prefix(3).map { $0 },
            topLosers: metrics.filter { $0.gainLoss < 0 }.sorted { $0.gainLossPercent < $1.gainLossPercent }.prefix(3).map { $0 }
        )
    }
}
