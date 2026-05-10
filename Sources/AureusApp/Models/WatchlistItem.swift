import Foundation
import SwiftData

@Model
final class WatchlistItem {
    @Attribute(.unique) var id: UUID
    var ticker: String
    var name: String
    var latestPrice: Double?
    var previousClose: Double?
    var lastUpdated: Date?
    var note: String

    init(
        id: UUID = UUID(),
        ticker: String,
        name: String = "",
        latestPrice: Double? = nil,
        previousClose: Double? = nil,
        lastUpdated: Date? = nil,
        note: String = ""
    ) {
        self.id = id
        self.ticker = ticker.uppercased()
        self.name = name
        self.latestPrice = latestPrice
        self.previousClose = previousClose
        self.lastUpdated = lastUpdated
        self.note = note
    }
}
