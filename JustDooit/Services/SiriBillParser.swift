import Foundation

enum SiriBillParser {
    private static let unitSuffix = try! Regex(#"\s+(?:porsi|gelas|buah|pcs|unit|portions?)$"#).ignoresCase()
    private static let percentSuffix = try! Regex(#"\s*(?:%|persen|percent)$"#).ignoresCase()
    private static let forSeparator = try! Regex(#"\s+(?:untuk|for)\s+"#).ignoresCase()
    private static let nameListSeparator = try! Regex(#"\s+(?:dan|and)\s+|[;&]"#).ignoresCase()
    private static let decimalPercent = try! Regex(#"^[0-9]+[.,][0-9]{1,2}$"#)

    static func key(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "id_ID"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func rows(_ text: String, commas: Bool = false) -> [String] {
        let pattern = commas ? #"[;\n]|\s+(?:lalu|kemudian|then)\s+|,\s*(?=\p{L})"# : #"[;\n]|\s+(?:lalu|kemudian|then)\s+"#
        guard let regex = try? Regex(pattern).ignoresCase() else { return [text] }
        return text.replacing(regex, with: ";")
            .components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    static func items(_ text: String) throws -> [SiriReceiptItem] {
        guard text.count <= 4_000 else { throw SiriEntryError.invalidItems }
        let entries = rows(text, commas: true)
        guard (1...20).contains(entries.count) else { throw SiriEntryError.invalidItems }
        var seen: Set<String> = []
        return try entries.map { row in
            let patterns = [#"^(.+?)\s+(?:jumlah|quantity)\s+(.+?)\s+(?:harga(?:\s+satuan)?|unit price)\s+(.+)$"#,
                            #"^(.+?)\s+([0-9]+)\s*(?:x|×|kali)\s*(.+)$"#]
            guard let fields = patterns.compactMap({ captures($0, in: row) }).first else { throw SiriEntryError.invalidItems }
            let name = try SiriEntryValidator.title(fields[0])
            guard seen.insert(key(name)).inserted else { throw SiriEntryError.invalidItems }
            let qtyText = fields[1].replacing(unitSuffix, with: "")
            guard let qty = try? SiriSpokenNumber.integer(qtyText), (1...99).contains(qty),
                  let price = try? SiriSpokenNumber.integer(fields[2]), price > 0,
                  Double(qty) * Double(price) <= 1_000_000_000 else { throw SiriEntryError.invalidItems }
            return SiriReceiptItem(name: name, quantity: qty, unitPrice: Double(price))
        }
    }

    static func charges(_ text: String, subtotal: Double) throws -> SiriBillCharges {
        let input = key(text)
        if ["tidak ada", "tanpa tambahan", "none", "no extras", "nol", "zero", "0"].contains(input) { return SiriBillCharges() }
        guard text.count <= 2_000 else { throw SiriEntryError.invalidCharges }
        let entries = rows(text, commas: true)
        guard (1...10).contains(entries.count) else { throw SiriEntryError.invalidCharges }
        var result = SiriBillCharges()
        var seen: Set<String> = []
        let numberStarts = #"[0-9]|nol|zero|satu|one|dua|two|tiga|three|empat|four|lima|five|enam|six|tujuh|seven|delapan|eight|sembilan|nine|sepuluh|ten|sebelas|eleven|seratus|seribu|sejuta|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|rp|idr"#
        for row in entries {
            guard let fields = captures(#"^(.+?)\s+((?:\#(numberStarts)).*)$"#, in: row) else { throw SiriEntryError.invalidCharges }
            let name = try SiriEntryValidator.title(fields[0])
            let label = key(name)
            guard seen.insert(label).inserted else { throw SiriEntryError.invalidCharges }
            let percent = fields[1].contains(percentSuffix)
            let number = fields[1].replacing(percentSuffix, with: "")
            let value: Double
            if percent, number.contains(decimalPercent) {
                value = Double(number.replacing(",", with: ".")) ?? -1
            } else if let parsed = try? SiriSpokenNumber.integer(number) { value = Double(parsed) }
            else { throw SiriEntryError.invalidCharges }
            guard value >= 0, value <= (percent ? 100 : 1_000_000_000) else { throw SiriEntryError.invalidCharges }
            if ["diskon", "discount"].contains(label) {
                guard !seen.contains("__discount") else { throw SiriEntryError.invalidCharges }
                seen.insert("__discount")
                result.discount = percent ? (subtotal * value / 100).rounded() : value
                guard result.discount <= subtotal else { throw SiriEntryError.invalidCharges }
            } else {
                result.charges.append(SplitBillCharge(name: name, value: value, kind: percent ? .percentage : .fixed))
            }
        }
        return result
    }

    static func assignments(_ text: String, items: [SiriReceiptItem], participants: [SplitParticipant]) throws -> [SplitItem] {
        guard text.count <= 6_000 else { throw SiriEntryError.invalidAssignments }
        let entries = rows(text)
        guard entries.count == items.count else { throw SiriEntryError.invalidAssignments }
        var assigned: Set<String> = []
        var result: [SplitItem] = []
        for row in entries {
            let parts = row.replacing(forSeparator, with: ":").components(separatedBy: ":")
            guard parts.count == 2, let item = items.first(where: { key($0.name) == key(parts[0]) }),
                  assigned.insert(key(item.name)).inserted else { throw SiriEntryError.invalidAssignments }
            let names = parts[1].replacing(nameListSeparator, with: ",")
                .components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            var receivers: [(SplitParticipant, Int?)] = []
            var seen: Set<UUID> = []
            for name in names {
                let normalizedName = key(name)
                let aliases: Set<String> = ["aku", "me", "myself", "i"]
                let exactKey = aliases.contains(normalizedName) ? "saya" : normalizedName
                let person: SplitParticipant
                let quantity: Int?
                if let exact = participants.first(where: { key($0.name) == exactKey }) {
                    person = exact
                    quantity = nil
                } else {
                    var match: (SplitParticipant, Int)?
                    for candidate in participants {
                        let labels = candidate.name == "Saya" ? ["saya", "aku", "me", "myself", "i"] : [key(candidate.name)]
                        for label in labels where normalizedName.hasPrefix(label + " ") {
                            let suffix = String(normalizedName.dropFirst(label.count + 1))
                                .replacing(unitSuffix, with: "")
                            if let count = try? SiriSpokenNumber.integer(suffix), (1...99).contains(count) {
                                guard match == nil else { throw SiriEntryError.invalidAssignments }
                                match = (candidate, count)
                            }
                        }
                    }
                    guard let match else { throw SiriEntryError.invalidAssignments }
                    person = match.0
                    quantity = match.1
                }
                guard seen.insert(person.id).inserted else { throw SiriEntryError.invalidAssignments }
                receivers.append((person, quantity))
            }
            guard !receivers.isEmpty else { throw SiriEntryError.invalidAssignments }
            if receivers.allSatisfy({ $0.1 == nil }) {
                result.append(SplitItem(name: item.name, price: item.unitPrice, quantity: item.quantity,
                                        assignedParticipantIds: Set(receivers.map { $0.0.id })))
            } else {
                guard receivers.allSatisfy({ ($0.1 ?? 0) > 0 }), receivers.reduce(0, { $0 + ($1.1 ?? 0) }) == item.quantity else { throw SiriEntryError.invalidAssignments }
                for (person, count) in receivers {
                    result.append(SplitItem(name: item.name, price: item.unitPrice, quantity: count ?? 1,
                                            assignedParticipantIds: [person.id]))
                }
            }
        }
        return result
    }

    private static func captures(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? Regex(pattern).ignoresCase(),
              let match = text.firstMatch(of: regex) else { return nil }
        return (1..<match.count).compactMap { index in
            match[index].substring.map(String.init)
        }
    }
}
