import Foundation
import SwiftData

@Model
final class ChartSeriesCache {
    @Attribute(.unique) var key: String
    var namespace: String
    var rangeRaw: String
    var dataVersion: String
    var updatedAt: Date
    @Attribute(.externalStorage) var payloadData: Data

    init(
        key: String,
        namespace: String,
        rangeRaw: String,
        dataVersion: String,
        updatedAt: Date = .now,
        payloadData: Data
    ) {
        self.key = key
        self.namespace = namespace
        self.rangeRaw = rangeRaw
        self.dataVersion = dataVersion
        self.updatedAt = updatedAt
        self.payloadData = payloadData
    }
}

struct ChartSeriesCachePayload: Codable {
    let points: [CachedNetWorthHistoryPoint]
}

struct CachedNetWorthHistoryPoint: Codable {
    let date: Date
    let totalValue: Double
    let investedAmount: Double
    let unrealizedGainLoss: Double

    init(_ point: NetWorthHistoryPoint) {
        date = point.date
        totalValue = point.totalValue
        investedAmount = point.investedAmount
        unrealizedGainLoss = point.unrealizedGainLoss
    }

    var historyPoint: NetWorthHistoryPoint {
        NetWorthHistoryPoint(
            date: date,
            totalValue: totalValue,
            investedAmount: investedAmount,
            unrealizedGainLoss: unrealizedGainLoss
        )
    }
}
