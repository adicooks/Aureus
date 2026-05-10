import Foundation

struct AureusBackup: Codable {
    var exportedAt: Date
    var holdings: [HoldingBackup]
    var snapshots: [NetWorthSnapshotBackup]
}

struct HoldingBackup: Codable {
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

    init(_ holding: Holding) {
        kindRaw = holding.kindRaw
        name = holding.name
        ticker = holding.ticker
        quantity = holding.quantity
        purchaseDate = holding.purchaseDate
        purchasePrice = holding.purchasePrice
        fees = holding.fees
        notes = holding.notes
        principalAmount = holding.principalAmount
        interestRate = holding.interestRate
        maturityDate = holding.maturityDate
        customCategory = holding.customCategory
        manualCurrentValue = holding.manualCurrentValue
        latestPrice = holding.latestPrice
        previousClose = holding.previousClose
        lastPriceUpdate = holding.lastPriceUpdate
    }

    func makeHolding() -> Holding {
        Holding(
            kind: AssetKind(rawValue: kindRaw) ?? .custom,
            name: name,
            ticker: ticker,
            quantity: quantity,
            purchaseDate: purchaseDate,
            purchasePrice: purchasePrice,
            fees: fees,
            notes: notes,
            principalAmount: principalAmount,
            interestRate: interestRate,
            maturityDate: maturityDate,
            customCategory: customCategory,
            manualCurrentValue: manualCurrentValue,
            latestPrice: latestPrice,
            previousClose: previousClose,
            lastPriceUpdate: lastPriceUpdate
        )
    }
}

struct NetWorthSnapshotBackup: Codable {
    var date: Date
    var totalValue: Double
    var investedAmount: Double
    var unrealizedGainLoss: Double
    var note: String

    init(_ snapshot: NetWorthSnapshot) {
        date = snapshot.date
        totalValue = snapshot.totalValue
        investedAmount = snapshot.investedAmount
        unrealizedGainLoss = snapshot.unrealizedGainLoss
        note = snapshot.note
    }

    func makeSnapshot() -> NetWorthSnapshot {
        NetWorthSnapshot(date: date, totalValue: totalValue, investedAmount: investedAmount, unrealizedGainLoss: unrealizedGainLoss, note: note)
    }
}

enum BackupService {
    static func encode(holdings: [Holding], snapshots: [NetWorthSnapshot]) throws -> Data {
        let backup = AureusBackup(
            exportedAt: .now,
            holdings: holdings.map(HoldingBackup.init),
            snapshots: snapshots.map(NetWorthSnapshotBackup.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> AureusBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AureusBackup.self, from: data)
    }
}
