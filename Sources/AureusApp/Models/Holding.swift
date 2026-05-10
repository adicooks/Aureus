import Foundation
import SwiftData

@Model
final class Holding {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var name: String
    var ticker: String
    var quantity: Double
    var purchaseDate: Date
    var purchasePrice: Double
    var fees: Double
    var notes: String
    var principalAmount: Double
    var interestRate: Double
    var maturityDate: Date?
    var customCategory: String
    var manualCurrentValue: Double
    var latestPrice: Double?
    var previousClose: Double?
    var lastPriceUpdate: Date?
    var sector: String?
    var industry: String?
    var dividendYield: Double?
    var website: String?
    var logoURL: String?
    var exchangeName: String?
    var currencyCode: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \PriceSnapshot.holding)
    var priceSnapshots: [PriceSnapshot]

    @Relationship(deleteRule: .cascade, inverse: \Transaction.holding)
    var transactions: [Transaction]

    init(
        id: UUID = UUID(),
        kind: AssetKind,
        name: String,
        ticker: String = "",
        quantity: Double = 0,
        purchaseDate: Date = .now,
        purchasePrice: Double = 0,
        fees: Double = 0,
        notes: String = "",
        principalAmount: Double = 0,
        interestRate: Double = 0,
        maturityDate: Date? = nil,
        customCategory: String = "",
        manualCurrentValue: Double = 0,
        latestPrice: Double? = nil,
        previousClose: Double? = nil,
        lastPriceUpdate: Date? = nil,
        sector: String? = nil,
        industry: String? = nil,
        dividendYield: Double? = nil,
        website: String? = nil,
        logoURL: String? = nil,
        exchangeName: String? = nil,
        currencyCode: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.name = name
        self.ticker = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.quantity = quantity
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.fees = fees
        self.notes = notes
        self.principalAmount = principalAmount
        self.interestRate = interestRate
        self.maturityDate = maturityDate
        self.customCategory = customCategory
        self.manualCurrentValue = manualCurrentValue
        self.latestPrice = latestPrice
        self.previousClose = previousClose
        self.lastPriceUpdate = lastPriceUpdate
        self.sector = sector
        self.industry = industry
        self.dividendYield = dividendYield
        self.website = website
        self.logoURL = logoURL
        self.exchangeName = exchangeName
        self.currencyCode = currencyCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.priceSnapshots = []
        self.transactions = []
    }

    var kind: AssetKind {
        get { AssetKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }

    var displayTicker: String {
        ticker.isEmpty ? "Manual" : ticker
    }

    var costBasis: Double {
        switch kind {
        case .bond:
            return max(0, principalAmount == 0 ? purchasePrice : purchasePrice) + fees
        case .cash, .realEstate, .business, .collectible, .custom:
            return purchasePrice + fees
        case .stock, .etf, .crypto:
            return max(0, quantity * purchasePrice + fees)
        }
    }

    var currentValue: Double {
        switch kind {
        case .stock, .etf, .crypto:
            return max(0, quantity * (latestPrice ?? purchasePrice))
        case .bond:
            return manualCurrentValue > 0 ? manualCurrentValue : principalAmount
        case .cash, .realEstate, .business, .collectible, .custom:
            return manualCurrentValue
        }
    }

    var previousValue: Double? {
        guard let previousClose, kind.isMarketPriced else { return nil }
        return max(0, quantity * previousClose)
    }

    var gainLoss: Double {
        currentValue - costBasis
    }

    var gainLossPercent: Double {
        guard costBasis > 0 else { return 0 }
        return gainLoss / costBasis
    }

    var dailyChange: Double? {
        guard let previousValue else { return nil }
        return currentValue - previousValue
    }

    func apply(price: QuotePrice, at date: Date = .now) {
        latestPrice = price.regularMarketPrice
        previousClose = price.previousClose
        ticker = price.symbol
        exchangeName = price.exchangeName
        currencyCode = price.currency
        lastPriceUpdate = date
        updatedAt = date
    }

    func apply(profile: MarketAssetProfile, at date: Date = .now, updateName: Bool = false) {
        ticker = profile.symbol
        if updateName {
            if let longName = profile.longName, !longName.isEmpty {
                name = longName
            } else if let shortName = profile.shortName, !shortName.isEmpty {
                name = shortName
            }
        }
        sector = profile.sector
        industry = profile.industry
        dividendYield = profile.dividendYield
        website = profile.website
        logoURL = profile.logoURL
        exchangeName = profile.exchangeName ?? exchangeName
        currencyCode = profile.currency ?? currencyCode
        updatedAt = date
    }
}
