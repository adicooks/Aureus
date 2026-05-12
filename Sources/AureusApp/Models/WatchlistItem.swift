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
    var sector: String?
    var industry: String?
    var logoURL: String?
    var note: String

    init(
        id: UUID = UUID(),
        ticker: String,
        name: String = "",
        latestPrice: Double? = nil,
        previousClose: Double? = nil,
        lastUpdated: Date? = nil,
        sector: String? = nil,
        industry: String? = nil,
        logoURL: String? = nil,
        note: String = ""
    ) {
        self.id = id
        self.ticker = ticker.uppercased()
        self.name = name
        self.latestPrice = latestPrice
        self.previousClose = previousClose
        self.lastUpdated = lastUpdated
        self.sector = sector
        self.industry = industry
        self.logoURL = logoURL
        self.note = note
    }

    func apply(quote: QuotePrice, at date: Date = .now) {
        ticker = quote.symbol
        latestPrice = quote.regularMarketPrice
        previousClose = quote.previousClose
        lastUpdated = date
        if name.isEmpty {
            name = quote.longName ?? quote.shortName ?? name
        }
    }

    func apply(profile: MarketAssetProfile) {
        name = profile.longName ?? profile.shortName ?? name
        sector = profile.sector
        industry = profile.industry
        logoURL = profile.logoURL
    }
}
