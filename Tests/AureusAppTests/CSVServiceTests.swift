import XCTest
@testable import AureusApp

final class CSVServiceTests: XCTestCase {
    func testHeaderlessTickerLotImportCreatesStockHoldings() throws {
        let csv = """
        PANW,5,8/19/2024,341.48,Sold 8/28/2024 at 351.45
        NVDA,10,8/5/2024,91.96,Holding
        VNOM,50,5/11/2026,46.70,Holding
        """

        let holdings = try CSVService.parse(csv)

        XCTAssertEqual(holdings.count, 3)
        XCTAssertEqual(holdings[0].kind, .stock)
        XCTAssertEqual(holdings[0].name, "PANW")
        XCTAssertEqual(holdings[0].ticker, "PANW")
        XCTAssertEqual(holdings[0].quantity, 5, accuracy: 0.001)
        XCTAssertEqual(holdings[0].purchasePrice, 341.48, accuracy: 0.001)
        XCTAssertTrue(holdings[0].isArchived)
        XCTAssertEqual(holdings[1].currentValue, 919.60, accuracy: 0.001)
        XCTAssertFalse(holdings[1].isArchived)
        XCTAssertEqual(holdings[2].ticker, "VNOM")
    }

    func testHeaderlessGoldImportUsesYahooGoldFuturesTicker() throws {
        let csv = "GOLD,1,8/21/2024,2500,Holding"

        let holdings = try CSVService.parse(csv)

        XCTAssertEqual(holdings.count, 1)
        XCTAssertEqual(holdings[0].name, "Gold")
        XCTAssertEqual(holdings[0].ticker, "GC=F")
        XCTAssertEqual(holdings[0].kind, .commodity)
        XCTAssertEqual(holdings[0].currentValue, 2_500, accuracy: 0.001)
    }

    func testHeaderedExportImportStillWorks() throws {
        let original = Holding(
            kind: .stock,
            name: "NVIDIA",
            ticker: "NVDA",
            quantity: 10,
            purchasePrice: 91.96,
            notes: "Long term"
        )

        let holdings = try CSVService.parse(CSVService.export(holdings: [original]))

        XCTAssertEqual(holdings.count, 1)
        XCTAssertEqual(holdings[0].kind, .stock)
        XCTAssertEqual(holdings[0].name, "NVIDIA")
        XCTAssertEqual(holdings[0].ticker, "NVDA")
        XCTAssertEqual(holdings[0].quantity, 10, accuracy: 0.001)
        XCTAssertEqual(holdings[0].purchasePrice, 91.96, accuracy: 0.001)
        XCTAssertEqual(holdings[0].notes, "Long term")
    }
}
