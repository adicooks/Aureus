import Foundation
import SwiftData

enum SnapshotService {
    static func saveDailySnapshotIfNeeded(holdings: [Holding], snapshots: [NetWorthSnapshot], context: ModelContext) {
        let calendar = Calendar.current
        guard !snapshots.contains(where: { calendar.isDateInToday($0.date) }) else { return }
        saveSnapshot(holdings: holdings, context: context, note: "Daily snapshot")
    }

    static func saveSnapshot(holdings: [Holding], context: ModelContext, note: String = "Manual snapshot") {
        let summary = PortfolioCalculator.summarize(holdings)
        let snapshot = NetWorthSnapshot(
            totalValue: summary.totalNetWorth,
            investedAmount: summary.totalInvested,
            unrealizedGainLoss: summary.unrealizedGainLoss,
            note: note
        )
        context.insert(snapshot)
        try? context.save()
    }
}
