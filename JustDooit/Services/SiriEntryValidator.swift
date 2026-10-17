import Foundation

enum SiriEntryValidator {
    private static let andAfterPunctuation = try! Regex(#"[,;]\s*(?:dan|and)\s+"#).ignoresCase()
    private static let andSeparator = try! Regex(#"\s+(?:dan|and)\s+"#).ignoresCase()
    private static let listPunctuation = try! Regex(#"[;\n&]"#)

    static func amount(_ value: Double) throws -> Int {
        guard value.isFinite, value > 0, value <= 1_000_000_000,
              value.rounded(.towardZero) == value else { throw SiriEntryError.invalidAmount }
        return Int(value)
    }

    /// Siri dictation ends answers with "." even when the answer is a single name.
    static func withoutTrailingPunctuation(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!?")))
    }

    static func title(_ value: String) throws -> String {
        let clean = withoutTrailingPunctuation(value)
        guard !clean.isEmpty, clean.count <= 120,
              !clean.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw SiriEntryError.invalidTitle
        }
        return clean
    }

    /// Names are manual participants, never guessed contacts. The owner always appears once.
    static func participants(_ value: String) throws -> [SplitParticipant] {
        guard value.count <= 1_000 else { throw SiriEntryError.invalidParticipants }
        let separated = withoutTrailingPunctuation(value)
            .replacing(andAfterPunctuation, with: ",")
            .replacing(andSeparator, with: ",")
            .replacing(listPunctuation, with: ",")
        let names = separated.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var result = [SplitParticipant(name: "Saya", phoneNumber: "")]
        var seen: Set<String> = []
        let ownerAliases: Set<String> = ["saya", "aku", "saya sendiri", "me", "myself", "i"]
        var ownerWasSpoken = false
        let allowed = CharacterSet.letters.union(.whitespaces).union(CharacterSet(charactersIn: "-'.’"))
        for name in names {
            guard !name.isEmpty, name.count <= 60, name.unicodeScalars.allSatisfy(allowed.contains),
                  name.unicodeScalars.contains(where: CharacterSet.letters.contains),
                  !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
                throw SiriEntryError.invalidParticipants
            }
            let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "id_ID"))
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if ownerAliases.contains(key) {
                guard !ownerWasSpoken else { throw SiriEntryError.invalidParticipants }
                ownerWasSpoken = true
                continue
            }
            guard seen.insert(key).inserted else { throw SiriEntryError.invalidParticipants }
            result.append(SplitParticipant(name: name, phoneNumber: ""))
        }
        guard (2...10).contains(result.count) else { throw SiriEntryError.invalidParticipants }
        return result
    }
}
