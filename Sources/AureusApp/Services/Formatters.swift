import Foundation

enum Formatters {
    static let currency: FloatingPointFormatStyle<Double>.Currency = .currency(code: Locale.current.currency?.identifier ?? "USD")
    static let percent: FloatingPointFormatStyle<Double>.Percent = .percent.precision(.fractionLength(2))
    static let number: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0...4))

    static let shortDate: Date.FormatStyle = .dateTime.month(.abbreviated).day().year()
    static let compactDate: Date.FormatStyle = .dateTime.month(.abbreviated).day()
    static let time: Date.FormatStyle = .dateTime.hour().minute()
}
