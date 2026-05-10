import Foundation
import SwiftData

@Model
final class NetWorthSnapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var totalValue: Double
    var investedAmount: Double
    var unrealizedGainLoss: Double
    var note: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        totalValue: Double,
        investedAmount: Double,
        unrealizedGainLoss: Double,
        note: String = ""
    ) {
        self.id = id
        self.date = date
        self.totalValue = totalValue
        self.investedAmount = investedAmount
        self.unrealizedGainLoss = unrealizedGainLoss
        self.note = note
    }
}
