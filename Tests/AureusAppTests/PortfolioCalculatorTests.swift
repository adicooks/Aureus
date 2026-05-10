import XCTest
@testable import AureusApp

final class PortfolioCalculatorTests: XCTestCase {
    func testSummaryCalculatesTotalsAndAllocation() {
        let stock = Holding(kind: .stock, name: "Example", ticker: "EXM", quantity: 10, purchasePrice: 20, fees: 5, latestPrice: 30, previousClose: 28)
        let cash = Holding(kind: .cash, name: "Cash", purchasePrice: 100, manualCurrentValue: 100)

        let summary = PortfolioCalculator.summarize([stock, cash])

        XCTAssertEqual(summary.totalNetWorth, 400, accuracy: 0.001)
        XCTAssertEqual(summary.totalInvested, 305, accuracy: 0.001)
        XCTAssertEqual(summary.unrealizedGainLoss, 95, accuracy: 0.001)
        XCTAssertEqual(summary.dailyChange ?? 0, 20, accuracy: 0.001)
        XCTAssertEqual(summary.metrics.first(where: { $0.holding.id == stock.id })?.allocation ?? 0, 0.75, accuracy: 0.001)
    }
}
