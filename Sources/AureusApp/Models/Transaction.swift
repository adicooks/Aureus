import Foundation
import SwiftData

enum TransactionKind: String, CaseIterable, Codable, Identifiable {
    case buy
    case sell
    case dividend
    case deposit
    case withdrawal
    case interest
    case adjustment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buy: "Buy"
        case .sell: "Sell"
        case .dividend: "Dividend"
        case .deposit: "Deposit"
        case .withdrawal: "Withdrawal"
        case .interest: "Interest"
        case .adjustment: "Adjustment"
        }
    }

    var symbol: String {
        switch self {
        case .buy: "plus.circle"
        case .sell: "minus.circle"
        case .dividend: "dollarsign.circle"
        case .deposit: "arrow.down.to.line"
        case .withdrawal: "arrow.up.to.line"
        case .interest: "percent"
        case .adjustment: "slider.horizontal.3"
        }
    }
}

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var date: Date
    var quantity: Double
    var price: Double
    var fees: Double
    var note: String
    var holding: Holding?

    init(
        id: UUID = UUID(),
        kind: TransactionKind,
        date: Date = .now,
        quantity: Double = 0,
        price: Double = 0,
        fees: Double = 0,
        note: String = "",
        holding: Holding? = nil
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.date = date
        self.quantity = quantity
        self.price = price
        self.fees = fees
        self.note = note
        self.holding = holding
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .adjustment }
        set { kindRaw = newValue.rawValue }
    }

    var grossAmount: Double {
        let calculated = quantity * price
        return calculated == 0 ? price : calculated
    }

    var signedAmount: Double {
        switch kind {
        case .buy, .withdrawal:
            return -(grossAmount + fees)
        case .sell:
            return grossAmount - fees
        case .dividend, .deposit, .interest, .adjustment:
            return grossAmount - fees
        }
    }
}
