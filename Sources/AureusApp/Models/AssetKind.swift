import SwiftUI

enum AssetKind: String, CaseIterable, Codable, Identifiable {
    case stock
    case etf
    case bond
    case cash
    case crypto
    case realEstate
    case business
    case collectible
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stock: "Stocks"
        case .etf: "ETFs"
        case .bond: "Bonds"
        case .cash: "Cash"
        case .crypto: "Crypto"
        case .realEstate: "Real Estate"
        case .business: "Business"
        case .collectible: "Collectibles"
        case .custom: "Other"
        }
    }

    var singularTitle: String {
        switch self {
        case .stock: "Stock"
        case .etf: "ETF"
        case .bond: "Bond"
        case .cash: "Cash"
        case .crypto: "Crypto"
        case .realEstate: "Real Estate"
        case .business: "Business"
        case .collectible: "Collectible"
        case .custom: "Custom Asset"
        }
    }

    var symbol: String {
        switch self {
        case .stock: "chart.line.uptrend.xyaxis"
        case .etf: "square.stack.3d.up"
        case .bond: "doc.text"
        case .cash: "banknote"
        case .crypto: "bitcoinsign.circle"
        case .realEstate: "house"
        case .business: "building.2"
        case .collectible: "sparkles"
        case .custom: "shippingbox"
        }
    }

    var tint: Color {
        switch self {
        case .stock: .green
        case .etf: .teal
        case .bond: .blue
        case .cash: .mint
        case .crypto: .orange
        case .realEstate: .indigo
        case .business: .purple
        case .collectible: .pink
        case .custom: .secondary
        }
    }

    var isMarketPriced: Bool {
        self == .stock || self == .etf || self == .crypto
    }
}
