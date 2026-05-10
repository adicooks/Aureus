import Foundation

enum CSVService {
    static func export(holdings: [Holding]) -> String {
        let header = [
            "kind", "name", "ticker", "quantity", "purchaseDate", "purchasePrice", "fees",
            "principalAmount", "interestRate", "maturityDate", "currentValue", "notes"
        ].joined(separator: ",")

        let rows = holdings.map { holding in
            [
                holding.kind.rawValue,
                holding.name,
                holding.ticker,
                String(holding.quantity),
                ISO8601DateFormatter().string(from: holding.purchaseDate),
                String(holding.purchasePrice),
                String(holding.fees),
                String(holding.principalAmount),
                String(holding.interestRate),
                holding.maturityDate.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                String(holding.currentValue),
                holding.notes
            ].map(escape).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    static func parse(_ csv: String) throws -> [Holding] {
        let lines = csv.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 1 else { return [] }
        let header = splitCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var holdings: [Holding] = []
        let dateFormatter = ISO8601DateFormatter()

        for line in lines.dropFirst() where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let values = splitCSVLine(line)
            let row = Dictionary(uniqueKeysWithValues: zip(header, values))
            let kind = AssetKind(rawValue: row["kind"] ?? "") ?? .custom
            let purchaseDate = row["purchaseDate"].flatMap(dateFormatter.date(from:)) ?? .now
            let maturityDate = row["maturityDate"].flatMap(dateFormatter.date(from:))
            holdings.append(Holding(
                kind: kind,
                name: row["name"] ?? "Imported Asset",
                ticker: row["ticker"] ?? "",
                quantity: Double(row["quantity"] ?? "") ?? 0,
                purchaseDate: purchaseDate,
                purchasePrice: Double(row["purchasePrice"] ?? "") ?? 0,
                fees: Double(row["fees"] ?? "") ?? 0,
                notes: row["notes"] ?? "",
                principalAmount: Double(row["principalAmount"] ?? "") ?? 0,
                interestRate: Double(row["interestRate"] ?? "") ?? 0,
                maturityDate: maturityDate,
                manualCurrentValue: Double(row["currentValue"] ?? "") ?? 0
            ))
        }
        return holdings
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func splitCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if inQuotes, let next = iterator.next() {
                    if next == "\"" {
                        current.append("\"")
                    } else {
                        inQuotes.toggle()
                        if next != "," { current.append(next) } else {
                            values.append(current)
                            current = ""
                        }
                    }
                } else {
                    inQuotes.toggle()
                }
            } else if character == ",", !inQuotes {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        values.append(current)
        return values
    }
}
