import Foundation

/// Controlled number grammar. Unknown words or ambiguous decimals are rejected, never guessed.
enum SiriSpokenNumber {
    private static let currencyAffix = try! Regex(#"^(rp\.?|idr)\s*|\s*(rupiah|rupiahs)$"#)
    private static let groupedDigits = try! Regex(#"^(?:[0-9]+|[0-9]{1,3}(?:[.,][0-9]{3})+)$"#)

    static func integer(_ raw: String) throws -> Int {
        var text = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacing(currencyAffix, with: "")
        if text.contains(groupedDigits),
           let value = Int(text.filter(\.isNumber)), value <= 1_000_000_000 { return value }
        let substitutions = ["seratus": "satu ratus", "seribu": "satu ribu", "sejuta": "satu juta"]
        for (word, replacement) in substitutions { text = text.replacing(word, with: replacement) }
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { throw SiriEntryError.invalidAmount }
        let scales = ["miliar": 1_000_000_000, "billion": 1_000_000_000, "juta": 1_000_000, "million": 1_000_000, "ribu": 1_000, "thousand": 1_000]
        var total = 0
        var group: [String] = []
        var priorScale = Int.max
        for token in tokens {
            if let scale = scales[token] {
                guard scale < priorScale, !group.isEmpty else { throw SiriEntryError.invalidAmount }
                let value = try small(group)
                guard value > 0 else { throw SiriEntryError.invalidAmount }
                total += value * scale
                guard total <= 1_000_000_000 else { throw SiriEntryError.invalidAmount }
                priorScale = scale
                group = []
            } else { group.append(token) }
        }
        if !group.isEmpty { total += try small(group) }
        guard total <= 1_000_000_000 else { throw SiriEntryError.invalidAmount }
        return total
    }

    private static func small(_ tokens: [String]) throws -> Int {
        let units = ["nol":0,"zero":0,"satu":1,"one":1,"dua":2,"two":2,"tiga":3,"three":3,"empat":4,"four":4,"lima":5,"five":5,"enam":6,"six":6,"tujuh":7,"seven":7,"delapan":8,"eight":8,"sembilan":9,"nine":9]
        let special = ["sepuluh":10,"ten":10,"sebelas":11,"eleven":11,"twelve":12,"thirteen":13,"fourteen":14,"fifteen":15,"sixteen":16,"seventeen":17,"eighteen":18,"nineteen":19]
        let tens = ["twenty":20,"thirty":30,"forty":40,"fifty":50,"sixty":60,"seventy":70,"eighty":80,"ninety":90]
        var rest = tokens
        var value = 0
        if rest.count >= 2, let n = units[rest[0]], n > 0, ["ratus", "hundred"].contains(rest[1]) {
            value = n * 100; rest.removeFirst(2)
            if rest.first == "and" { rest.removeFirst() }
        }
        if rest.isEmpty { return value }
        if rest.count == 1, let n = units[rest[0]] ?? special[rest[0]] ?? tens[rest[0]] { return value + n }
        if rest.count == 2, rest[1] == "belas", let n = units[rest[0]], n >= 2 { return value + 10 + n }
        if (2...3).contains(rest.count), rest[1] == "puluh", let n = units[rest[0]], n >= 2 {
            if rest.count == 2 { return value + n * 10 }
            if let tail = units[rest[2]], tail > 0 { return value + n * 10 + tail }
        }
        if rest.count == 2, let n = tens[rest[0]], let tail = units[rest[1]], tail > 0 { return value + n + tail }
        throw SiriEntryError.invalidAmount
    }
}
