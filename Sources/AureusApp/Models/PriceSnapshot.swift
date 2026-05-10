import Foundation
import SwiftData

@Model
final class PriceSnapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var price: Double
    var source: String
    var holding: Holding?

    init(id: UUID = UUID(), date: Date = .now, price: Double, source: String = "Yahoo Finance", holding: Holding? = nil) {
        self.id = id
        self.date = date
        self.price = price
        self.source = source
        self.holding = holding
    }
}
