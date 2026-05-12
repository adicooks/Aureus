import XCTest
@testable import AureusApp

final class HoldingTests: XCTestCase {
    func testProfileMetadataDoesNotRewriteTicker() {
        let holding = Holding(kind: .stock, name: "SARO", ticker: "SARO")
        let profile = MarketAssetProfile(
            symbol: "NSARO",
            shortName: "Bad Match",
            longName: "Bad Match Inc.",
            sector: "Technology",
            industry: "Software",
            dividendYield: nil,
            earningsDate: nil,
            website: nil,
            logoURL: nil,
            currency: nil,
            exchangeName: "NASDAQ"
        )

        holding.apply(profile: profile, updateName: true)

        XCTAssertEqual(holding.ticker, "SARO")
        XCTAssertEqual(holding.name, "Bad Match Inc.")
        XCTAssertEqual(holding.sector, "Technology")
    }
}
