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

    func testTopLosersExcludesProfitableHoldings() {
        let winner = Holding(kind: .stock, name: "Winner", ticker: "WIN", quantity: 2, purchasePrice: 50, latestPrice: 60)
        let summary = PortfolioCalculator.summarize([winner])

        XCTAssertEqual(summary.topGainers.count, 1)
        XCTAssertTrue(summary.topLosers.isEmpty)
    }

    func testNetWorthHistoryUsesPurchaseDateWhenNoSavedSnapshotsExist() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let purchaseDate = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        let stock = Holding(kind: .stock, name: "Example", ticker: "EXM", quantity: 10, purchaseDate: purchaseDate, purchasePrice: 20, latestPrice: 30)

        let series = PortfolioHistoryService.series(holdings: [stock], snapshots: [], range: .oneYear, now: now)

        XCTAssertEqual(series.count, 2)
        XCTAssertEqual(series.first?.totalValue ?? 0, 200, accuracy: 0.001)
        XCTAssertEqual(series.last?.totalValue ?? 0, 300, accuracy: 0.001)
    }

    func testOneDayNetWorthHistoryUsesLocalDayStartAndPreviousClose() {
        let calendar = Calendar.current
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let dayStart = calendar.startOfDay(for: now)
        let purchaseDate = calendar.date(byAdding: .day, value: -10, to: dayStart)!
        let stock = Holding(
            kind: .stock,
            name: "Example",
            ticker: "EXM",
            quantity: 10,
            purchaseDate: purchaseDate,
            purchasePrice: 90,
            latestPrice: 105,
            previousClose: 100
        )

        let series = PortfolioHistoryService.series(holdings: [stock], snapshots: [], range: .oneDay, now: now)

        XCTAssertEqual(series.first?.date, dayStart)
        XCTAssertEqual(series.first?.totalValue ?? 0, 1_000, accuracy: 0.001)
        XCTAssertEqual(series.last?.date, now)
        XCTAssertEqual(series.last?.totalValue ?? 0, 1_050, accuracy: 0.001)
    }
}
