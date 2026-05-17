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

        XCTAssertGreaterThanOrEqual(series.count, 2)
        XCTAssertEqual(series.first(where: { $0.totalValue > 0 })?.totalValue ?? 0, 200, accuracy: 0.001)
        XCTAssertEqual(series.last?.totalValue ?? 0, 300, accuracy: 0.001)
    }

    func testNetWorthHistoryIncludesRecentPurchaseDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let purchaseDate = now.addingTimeInterval(-3_600)
        let stock = Holding(kind: .stock, name: "Example", ticker: "EXM", quantity: 10, purchaseDate: purchaseDate, purchasePrice: 20, latestPrice: 30)

        let series = PortfolioHistoryService.series(holdings: [stock], snapshots: [], range: .oneYear, now: now)

        XCTAssertGreaterThanOrEqual(series.count, 2)
        XCTAssertTrue(series.contains { $0.date == purchaseDate })
        XCTAssertEqual(series.last?.date, now)
    }

    func testNetWorthHistoryUsesTransactionDatesAndQuantities() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let firstBuyDate = now.addingTimeInterval(-86_400 * 90)
        let secondBuyDate = now.addingTimeInterval(-86_400 * 30)
        let stock = Holding(kind: .stock, name: "Example", ticker: "EXM", quantity: 15, purchaseDate: firstBuyDate, purchasePrice: 15, latestPrice: 30)
        let firstBuy = Transaction(kind: .buy, date: firstBuyDate, quantity: 10, price: 10, holding: stock)
        let secondBuy = Transaction(kind: .buy, date: secondBuyDate, quantity: 5, price: 20, holding: stock)

        let series = PortfolioHistoryService.series(
            holdings: [stock],
            snapshots: [],
            range: .all,
            transactions: [firstBuy, secondBuy],
            now: now
        )

        XCTAssertEqual(series.first(where: { $0.date == firstBuyDate })?.totalValue ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(series.first(where: { $0.date == secondBuyDate })?.totalValue ?? 0, 300, accuracy: 0.001)
        XCTAssertEqual(series.last?.totalValue ?? 0, 450, accuracy: 0.001)
    }

    func testSameDaySnapshotsDoNotHideTransactionHistory() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let buyDate = now.addingTimeInterval(-86_400 * 30)
        let stock = Holding(kind: .stock, name: "Example", ticker: "EXM", quantity: 10, purchaseDate: buyDate, purchasePrice: 20, latestPrice: 30)
        let buy = Transaction(kind: .buy, date: buyDate, quantity: 10, price: 20, holding: stock)
        let snapshots = [
            NetWorthSnapshot(date: now.addingTimeInterval(-600), totalValue: 300, investedAmount: 200, unrealizedGainLoss: 100),
            NetWorthSnapshot(date: now, totalValue: 300, investedAmount: 200, unrealizedGainLoss: 100)
        ]

        let series = PortfolioHistoryService.series(
            holdings: [stock],
            snapshots: snapshots,
            range: .all,
            transactions: [buy],
            now: now
        )

        XCTAssertTrue(series.contains { $0.date == buyDate })
        XCTAssertEqual(series.first(where: { $0.date == buyDate })?.totalValue ?? 0, 200, accuracy: 0.001)
    }

    func testOneYearNetWorthHistorySamplesAboutTwiceWeekly() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let purchaseDate = now.addingTimeInterval(-86_400 * 365)
        let stock = Holding(kind: .stock, name: "Example", ticker: "EXM", quantity: 10, purchaseDate: purchaseDate, purchasePrice: 20, latestPrice: 30)

        let series = PortfolioHistoryService.series(holdings: [stock], snapshots: [], range: .oneYear, now: now)

        XCTAssertLessThanOrEqual(series.count, 108)
        XCTAssertGreaterThanOrEqual(series.count, 102)
    }

    func testAllNetWorthHistorySamplesWeekly() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let purchaseDate = now.addingTimeInterval(-86_400 * 365)
        let stock = Holding(kind: .stock, name: "Example", ticker: "EXM", quantity: 10, purchaseDate: purchaseDate, purchasePrice: 20, latestPrice: 30)

        let series = PortfolioHistoryService.series(holdings: [stock], snapshots: [], range: .all, now: now)

        XCTAssertLessThanOrEqual(series.count, 55)
        XCTAssertGreaterThanOrEqual(series.count, 52)
    }

    func testOneYearDisplaySeriesIsCappedForRendering() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let series = (0..<365).map { offset in
            NetWorthHistoryPoint(
                date: now.addingTimeInterval(Double(offset) * 86_400),
                totalValue: Double(offset),
                investedAmount: Double(offset),
                unrealizedGainLoss: 0
            )
        }

        let displaySeries = PortfolioHistoryService.displaySeries(series, for: .oneYear)

        XCTAssertLessThanOrEqual(displaySeries.count, 120)
        XCTAssertEqual(displaySeries.first?.date, series.first?.date)
        XCTAssertEqual(displaySeries.last?.date, series.last?.date)
    }

    func testAllDisplaySeriesIsCappedForRendering() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let series = (0..<800).map { offset in
            NetWorthHistoryPoint(
                date: now.addingTimeInterval(Double(offset) * 86_400),
                totalValue: Double(offset),
                investedAmount: Double(offset),
                unrealizedGainLoss: 0
            )
        }

        let displaySeries = PortfolioHistoryService.displaySeries(series, for: .all)

        XCTAssertLessThanOrEqual(displaySeries.count, 260)
        XCTAssertEqual(displaySeries.first?.date, series.first?.date)
        XCTAssertEqual(displaySeries.last?.date, series.last?.date)
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
