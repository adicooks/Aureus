import Foundation

enum CSVService {
    private static let exportedHeaderKeys: Set<String> = [
        "kind", "name", "ticker", "quantity", "purchasedate", "purchaseprice", "fees",
        "principalamount", "interestrate", "maturitydate", "currentvalue", "notes"
    ]

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
        let lines = csv.split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !lines.isEmpty else { return [] }

        let firstRow = splitCSVLine(lines[0]).map(normalizedHeaderKey)
        let hasHeader = firstRow.contains { exportedHeaderKeys.contains($0) }
        let header = hasHeader ? firstRow : []
        let dataLines = hasHeader ? Array(lines.dropFirst()) : lines
        var holdings: [Holding] = []

        for line in dataLines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let values = splitCSVLine(line)
            if hasHeader {
                let row = Dictionary(uniqueKeysWithValues: zip(header, values))
                holdings.append(parseHeaderedRow(row))
            } else if let holding = parseTickerLotRow(values) {
                holdings.append(holding)
            }
        }
        return holdings
    }

    private static func parseHeaderedRow(_ row: [String: String]) -> Holding {
        let purchaseDate = parseDate(value("purchasedate", in: row)) ?? .now
        let maturityDate = parseDate(value("maturitydate", in: row))
        let name = value("name", in: row)
        let ticker = normalizedImportedTicker(value("ticker", in: row), name: name)
        let kind = ticker == "GC=F" ? AssetKind.commodity : parseKind(value("kind", in: row))

        return Holding(
            kind: kind,
            name: name.isEmpty ? importedName(for: ticker) : name,
            ticker: ticker,
            quantity: parseDouble(value("quantity", in: row)),
            purchaseDate: purchaseDate,
            purchasePrice: parseDouble(value("purchaseprice", in: row)),
            fees: parseDouble(value("fees", in: row)),
            notes: value("notes", in: row),
            principalAmount: parseDouble(value("principalamount", in: row)),
            interestRate: parseDouble(value("interestrate", in: row)),
            maturityDate: maturityDate,
            manualCurrentValue: parseDouble(value("currentvalue", in: row))
        )
    }

    private static func parseTickerLotRow(_ values: [String]) -> Holding? {
        guard values.count >= 4 else { return nil }
        let ticker = normalizedImportedTicker(values[safe: 0] ?? "", name: "")
        guard isTickerLike(ticker) else { return nil }

        let notes = clean(values[safe: 4] ?? "")
        return Holding(
            kind: ticker == "GC=F" ? .commodity : .stock,
            name: importedName(for: ticker),
            ticker: ticker,
            quantity: parseDouble(values[safe: 1] ?? ""),
            purchaseDate: parseDate(values[safe: 2] ?? "") ?? .now,
            purchasePrice: parseDouble(values[safe: 3] ?? ""),
            notes: notes,
            isArchived: notes.localizedCaseInsensitiveContains("sold")
        )
    }

    private static func value(_ key: String, in row: [String: String]) -> String {
        clean(row[key] ?? "")
    }

    private static func normalizedHeaderKey(_ value: String) -> String {
        clean(value)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDouble(_ value: String) -> Double {
        let cleaned = clean(value)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "%", with: "")
        return Double(cleaned) ?? 0
    }

    private static func parseKind(_ value: String) -> AssetKind {
        let cleaned = clean(value)
        return AssetKind(rawValue: cleaned)
            ?? AssetKind.allCases.first { $0.rawValue.caseInsensitiveCompare(cleaned) == .orderedSame }
            ?? .custom
    }

    private static func normalizedImportedTicker(_ value: String, name: String) -> String {
        let ticker = clean(value).uppercased()
        let cleanName = clean(name)
        let isCommodityGold = cleanName.isEmpty || cleanName.caseInsensitiveCompare("Gold") == .orderedSame
        return ticker == "GOLD" && isCommodityGold ? "GC=F" : ticker
    }

    private static func importedName(for ticker: String) -> String {
        ticker == "GC=F" ? "Gold" : (ticker.isEmpty ? "Imported Asset" : ticker)
    }

    private static func parseDate(_ value: String) -> Date? {
        let cleaned = clean(value)
        guard !cleaned.isEmpty else { return nil }

        if let date = ISO8601DateFormatter().date(from: cleaned) {
            return date
        }

        for format in ["M/d/yyyy", "MM/dd/yyyy", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) {
                return date
            }
        }

        return nil
    }

    private static func isTickerLike(_ value: String) -> Bool {
        value.range(of: #"^[A-Z0-9.\-=^]{1,16}$"#, options: .regularExpression) != nil
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

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
