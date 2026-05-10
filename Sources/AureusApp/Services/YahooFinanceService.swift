import Foundation

struct QuotePrice: Codable, Equatable {
    let symbol: String
    let regularMarketPrice: Double
    let previousClose: Double?
    let currency: String?
    let exchangeName: String?
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
                exchangeName: result.meta.exchangeName
            )
        } catch let error as QuoteError {
            throw error
        } catch is DecodingError {
            throw QuoteError.invalidResponse
        } catch {
            throw QuoteError.yahooUnavailable
        }
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
    }

    struct Meta: Decodable {
        let currency: String?
        let symbol: String
        let exchangeName: String?
        let regularMarketPrice: Double?
        let previousClose: Double?
    }

    struct YahooError: Decodable {
        let code: String?
        let description: String?
    }
}
