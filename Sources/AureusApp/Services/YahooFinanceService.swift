import Foundation

struct QuotePrice: Codable, Equatable {
    let symbol: String
    let regularMarketPrice: Double
    let previousClose: Double?
    let currency: String?
    let exchangeName: String?
    let shortName: String?
    let longName: String?
}

struct MarketAssetProfile: Codable, Equatable {
    let symbol: String
    let shortName: String?
    let longName: String?
    let sector: String?
    let industry: String?
    let dividendYield: Double?
    let earningsDate: String?
    let website: String?
    let logoURL: String?
    let currency: String?
    let exchangeName: String?
}

struct HistoricalPricePoint: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let price: Double
}

enum QuoteError: LocalizedError {
    case invalidTicker
    case invalidResponse
    case noPriceFound
    case yahooUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidTicker: "Enter a valid ticker symbol."
        case .invalidResponse: "Yahoo Finance returned an unexpected response."
        case .noPriceFound: "No price was found for that ticker."
        case .yahooUnavailable: "Yahoo Finance is unavailable right now. Your cached prices are still shown."
        }
    }
}

struct YahooFinanceService {
    var session: URLSession = .shared
    private let logoDevToken = "pk_CReJbaehSA2igpPagRKLXg"

    func fetchQuote(for ticker: String) async throws -> QuotePrice {
        let symbol = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !symbol.isEmpty, symbol.range(of: #"^[A-Z0-9.\-=^]{1,16}$"#, options: .regularExpression) != nil else {
            throw QuoteError.invalidTicker
        }

        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)")!
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "5d")
        ]

        guard let url = components.url else { throw QuoteError.invalidTicker }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Aureus macOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw QuoteError.yahooUnavailable
            }
            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard decoded.chart.error == nil else { throw QuoteError.noPriceFound }
            guard let result = decoded.chart.result?.first, let price = result.meta.regularMarketPrice else {
                throw QuoteError.noPriceFound
            }
            return QuotePrice(
                symbol: result.meta.symbol.uppercased(),
                regularMarketPrice: price,
                previousClose: result.meta.previousClose,
                currency: result.meta.currency,
                exchangeName: result.meta.exchangeName,
                shortName: result.meta.shortName,
                longName: result.meta.longName
            )
        } catch let error as QuoteError {
            throw error
        } catch is DecodingError {
            throw QuoteError.invalidResponse
        } catch {
            throw QuoteError.yahooUnavailable
        }
    }

    func fetchProfile(for ticker: String) async throws -> MarketAssetProfile {
        let symbol = try normalizedSymbol(ticker)
        async let nasdaqSummary = fetchNasdaqSummary(for: symbol)
        async let nasdaqInfo = fetchNasdaqInfo(for: symbol)
        async let logoSearch = fetchTickerLogoResult(for: symbol)

        let summary = try? await nasdaqSummary
        let info = try? await nasdaqInfo
        let logo = try? await logoSearch

        if summary != nil || info != nil || logo != nil {
            let website = logo?.website
            let name = logo?.name ?? cleanCompanyName(info?.companyName)
            return MarketAssetProfile(
                symbol: (logo?.symbol ?? info?.symbol ?? summary?.symbol ?? symbol).uppercased(),
                shortName: name,
                longName: name,
                sector: summary?.sector,
                industry: summary?.industry,
                dividendYield: summary?.dividendYield,
                earningsDate: info?.earningsDate,
                website: website,
                logoURL: tickerLogoURL(for: website),
                currency: nil,
                exchangeName: summary?.exchangeName ?? info?.exchangeName ?? logo?.exchange
            )
        }

        return try await fetchYahooProfile(for: symbol)
    }

    func fetchPriceHistory(for ticker: String, from startDate: Date, to endDate: Date = .now) async throws -> [HistoricalPricePoint] {
        let symbol = try normalizedSymbol(ticker)
        let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encodedSymbol)")!
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "period1", value: "\(max(0, Int(startDate.timeIntervalSince1970)))"),
            URLQueryItem(name: "period2", value: "\(max(Int(startDate.timeIntervalSince1970) + 86_400, Int(endDate.timeIntervalSince1970)))")
        ]

        guard let url = components.url else { throw QuoteError.invalidTicker }
        var request = URLRequest(url: url)
        request.timeoutInterval = 16
        request.setValue("Aureus macOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw QuoteError.yahooUnavailable
            }
            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard decoded.chart.error == nil, let result = decoded.chart.result?.first else {
                throw QuoteError.noPriceFound
            }
            let closes = result.indicators?.quote.first?.close ?? []
            let timestamps = result.timestamp ?? []
            return zip(timestamps, closes).compactMap { timestamp, close in
                guard let close, close > 0 else { return nil }
                return HistoricalPricePoint(date: Date(timeIntervalSince1970: TimeInterval(timestamp)), price: close)
            }
        } catch let error as QuoteError {
            throw error
        } catch is DecodingError {
            throw QuoteError.invalidResponse
        } catch {
            throw QuoteError.yahooUnavailable
        }
    }

    private func fetchYahooProfile(for symbol: String) async throws -> MarketAssetProfile {
        let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var components = URLComponents(string: "https://query2.finance.yahoo.com/v10/finance/quoteSummary/\(encodedSymbol)")!
        components.queryItems = [
            URLQueryItem(name: "modules", value: "assetProfile,summaryDetail,price")
        ]

        guard let url = components.url else { throw QuoteError.invalidTicker }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Aureus macOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw QuoteError.yahooUnavailable
            }
            let decoded = try JSONDecoder().decode(YahooQuoteSummaryResponse.self, from: data)
            guard decoded.quoteSummary.error == nil, let result = decoded.quoteSummary.result?.first else {
                throw QuoteError.noPriceFound
            }
            let website = result.assetProfile?.website
            return MarketAssetProfile(
                symbol: (result.price?.symbol ?? symbol).uppercased(),
                shortName: result.price?.shortName,
                longName: result.price?.longName,
                sector: result.assetProfile?.sector,
                industry: result.assetProfile?.industry,
                dividendYield: result.summaryDetail?.dividendYield?.raw,
                earningsDate: nil,
                website: website,
                logoURL: tickerLogoURL(for: website),
                currency: result.price?.currency,
                exchangeName: result.price?.exchangeName
            )
        } catch let error as QuoteError {
            throw error
        } catch is DecodingError {
            throw QuoteError.invalidResponse
        } catch {
            throw QuoteError.yahooUnavailable
        }
    }

    private func fetchNasdaqSummary(for symbol: String) async throws -> NasdaqSummary {
        let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var components = URLComponents(string: "https://api.nasdaq.com/api/quote/\(encodedSymbol)/summary")!
        components.queryItems = [URLQueryItem(name: "assetclass", value: "stocks")]

        guard let url = components.url else { throw QuoteError.invalidTicker }
        let decoded: NasdaqSummaryResponse = try await fetchJSON(url: url, timeout: 12)
        guard let data = decoded.data, decoded.status.rCode < 400 else {
            throw QuoteError.noPriceFound
        }

        return NasdaqSummary(
            symbol: data.symbol.uppercased(),
            sector: usableValue(data.summaryData.Sector?.value),
            industry: usableValue(data.summaryData.Industry?.value),
            dividendYield: parsePercent(data.summaryData.Yield?.value),
            exchangeName: usableValue(data.summaryData.Exchange?.value)
        )
    }

    private func fetchNasdaqInfo(for symbol: String) async throws -> NasdaqInfo {
        let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var components = URLComponents(string: "https://api.nasdaq.com/api/quote/\(encodedSymbol)/info")!
        components.queryItems = [URLQueryItem(name: "assetclass", value: "stocks")]

        guard let url = components.url else { throw QuoteError.invalidTicker }
        let decoded: NasdaqInfoResponse = try await fetchJSON(url: url, timeout: 12)
        guard let data = decoded.data, decoded.status.rCode < 400 else {
            throw QuoteError.noPriceFound
        }

        return NasdaqInfo(
            symbol: data.symbol.uppercased(),
            companyName: data.companyName,
            exchangeName: data.exchange,
            earningsDate: extractEarningsDate(from: data.notifications)
        )
    }

    private func fetchTickerLogoResult(for symbol: String) async throws -> TickerLogoResult {
        var components = URLComponents(string: "https://www.allinvestview.com/api/logo-search/")!
        components.queryItems = [URLQueryItem(name: "q", value: symbol)]

        guard let url = components.url else { throw QuoteError.invalidTicker }
        let decoded: TickerLogoSearchResponse = try await fetchJSON(url: url, timeout: 10)
        guard let match = decoded.results.first(where: { $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame }) else {
            throw QuoteError.noPriceFound
        }
        return match
    }

    private func fetchJSON<Response: Decodable>(url: URL, timeout: TimeInterval) async throws -> Response {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Aureus", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw QuoteError.yahooUnavailable
            }
            return try JSONDecoder().decode(Response.self, from: data)
        } catch let error as QuoteError {
            throw error
        } catch is DecodingError {
            throw QuoteError.invalidResponse
        } catch {
            throw QuoteError.yahooUnavailable
        }
    }

    private func normalizedSymbol(_ ticker: String) throws -> String {
        let symbol = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !symbol.isEmpty, symbol.range(of: #"^[A-Z0-9.\-=^]{1,16}$"#, options: .regularExpression) != nil else {
            throw QuoteError.invalidTicker
        }
        return symbol
    }

    private func tickerLogoURL(for website: String?) -> String? {
        guard let domain = domain(from: website) else { return nil }
        return "https://img.logo.dev/\(domain)?token=\(logoDevToken)"
    }

    private func domain(from website: String?) -> String? {
        guard var website = usableValue(website) else { return nil }
        if !website.hasPrefix("http://"), !website.hasPrefix("https://") {
            website = "https://\(website)"
        }
        guard let host = URL(string: website)?.host()?.lowercased() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private func usableValue(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty, value != "N/A" else {
            return nil
        }
        return value
    }

    private func cleanCompanyName(_ name: String?) -> String? {
        guard var name = usableValue(name) else { return nil }
        let suffixes = [" Common Stock", " Ordinary Shares", " American Depositary Shares", " ADS", " Class A"]
        for suffix in suffixes where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parsePercent(_ value: String?) -> Double? {
        guard let value = usableValue(value) else { return nil }
        let cleaned = value
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let percent = Double(cleaned) else { return nil }
        return percent / 100
    }

    private func extractEarningsDate(from notifications: [NasdaqInfoResponse.Notification]?) -> String? {
        let messages = notifications?
            .flatMap(\.eventTypes)
            .filter {
                [$0.eventName, $0.message].contains { value in
                    value?.localizedCaseInsensitiveContains("earnings") == true
                }
            }
            .compactMap(\.message) ?? []

        guard let message = messages.first else { return nil }
        if let dateText = message.components(separatedBy: ":").last.map(usableValue), let dateText {
            return dateText
        }
        return usableValue(message)
    }
}

private struct YahooChartResponse: Decodable {
    let chart: Chart

    struct Chart: Decodable {
        let result: [Result]?
        let error: YahooError?
    }

    struct Result: Decodable {
        let meta: Meta
        let timestamp: [Int]?
        let indicators: Indicators?
    }

    struct Meta: Decodable {
        let currency: String?
        let symbol: String
        let exchangeName: String?
        let regularMarketPrice: Double?
        let previousClose: Double?
        let shortName: String?
        let longName: String?
    }

    struct Indicators: Decodable {
        let quote: [Quote]
    }

    struct Quote: Decodable {
        let close: [Double?]
    }

    struct YahooError: Decodable {
        let code: String?
        let description: String?
    }
}

private struct YahooQuoteSummaryResponse: Decodable {
    let quoteSummary: QuoteSummary

    struct QuoteSummary: Decodable {
        let result: [Result]?
        let error: YahooChartResponse.YahooError?
    }

    struct Result: Decodable {
        let assetProfile: AssetProfile?
        let summaryDetail: SummaryDetail?
        let price: Price?
    }

    struct AssetProfile: Decodable {
        let sector: String?
        let industry: String?
        let website: String?
    }

    struct SummaryDetail: Decodable {
        let dividendYield: RawValue?
    }

    struct Price: Decodable {
        let symbol: String?
        let shortName: String?
        let longName: String?
        let currency: String?
        let exchangeName: String?
    }

    struct RawValue: Decodable {
        let raw: Double?
    }
}

private struct NasdaqSummary {
    let symbol: String
    let sector: String?
    let industry: String?
    let dividendYield: Double?
    let exchangeName: String?
}

private struct NasdaqInfo {
    let symbol: String
    let companyName: String?
    let exchangeName: String?
    let earningsDate: String?
}

private struct NasdaqSummaryResponse: Decodable {
    let data: DataBlock?
    let status: Status

    struct DataBlock: Decodable {
        let symbol: String
        let summaryData: SummaryData
    }

    struct SummaryData: Decodable {
        let Exchange: ValueField?
        let Sector: ValueField?
        let Industry: ValueField?
        let Yield: ValueField?
    }

    struct ValueField: Decodable {
        let value: String?
    }

    struct Status: Decodable {
        let rCode: Int
    }
}

private struct NasdaqInfoResponse: Decodable {
    let data: DataBlock?
    let status: NasdaqSummaryResponse.Status

    struct DataBlock: Decodable {
        let symbol: String
        let companyName: String?
        let exchange: String?
        let notifications: [Notification]?
    }

    struct Notification: Decodable {
        let eventTypes: [EventType]
    }

    struct EventType: Decodable {
        let message: String?
        let eventName: String?
    }
}

private struct TickerLogoSearchResponse: Decodable {
    let results: [TickerLogoResult]
}

private struct TickerLogoResult: Decodable {
    let symbol: String
    let name: String?
    let website: String?
    let exchange: String?
}
