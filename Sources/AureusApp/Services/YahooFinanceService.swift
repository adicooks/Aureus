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
                website: website,
                logoURL: logoURL(for: website),
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

    private func normalizedSymbol(_ ticker: String) throws -> String {
        let symbol = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !symbol.isEmpty, symbol.range(of: #"^[A-Z0-9.\-=^]{1,16}$"#, options: .regularExpression) != nil else {
            throw QuoteError.invalidTicker
        }
        return symbol
    }

    private func logoURL(for website: String?) -> String? {
        guard
            let website,
            let url = URL(string: website.hasPrefix("http") ? website : "https://\(website)"),
            let host = url.host()
        else { return nil }
        return "https://logo.clearbit.com/\(host)"
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
