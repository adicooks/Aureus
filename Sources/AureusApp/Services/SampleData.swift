import Foundation

enum SampleData {
    static let holdings: [Holding] = [
        Holding(kind: .stock, name: "Apple", ticker: "AAPL", quantity: 12, purchaseDate: .now.addingTimeInterval(-86400 * 220), purchasePrice: 174.20, fees: 0, latestPrice: 210.40, previousClose: 208.12, lastPriceUpdate: .now.addingTimeInterval(-900)),
        Holding(kind: .etf, name: "Vanguard Total Stock Market ETF", ticker: "VTI", quantity: 18, purchaseDate: .now.addingTimeInterval(-86400 * 365), purchasePrice: 228.80, latestPrice: 271.11, previousClose: 270.04, lastPriceUpdate: .now.addingTimeInterval(-900)),
        Holding(kind: .bond, name: "Treasury Note 2030", purchaseDate: .now.addingTimeInterval(-86400 * 120), purchasePrice: 9_750, principalAmount: 10_000, interestRate: 4.2, maturityDate: .now.addingTimeInterval(86400 * 1_500), manualCurrentValue: 9_920),
        Holding(kind: .cash, name: "Emergency Fund", purchasePrice: 18_000, manualCurrentValue: 18_000),
        Holding(kind: .realEstate, name: "Home Equity", purchaseDate: .now.addingTimeInterval(-86400 * 900), purchasePrice: 145_000, manualCurrentValue: 182_000)
    ]

    static let snapshots: [NetWorthSnapshot] = stride(from: 11, through: 0, by: -1).map { monthOffset in
        let value = 185_000 + Double(11 - monthOffset) * 7_500 + Double.random(in: -3_500...4_200)
        return NetWorthSnapshot(
            date: Calendar.current.date(byAdding: .month, value: -monthOffset, to: .now) ?? .now,
            totalValue: value,
            investedAmount: value * 0.82,
            unrealizedGainLoss: value * 0.18,
            note: "Sample"
        )
    }
}
