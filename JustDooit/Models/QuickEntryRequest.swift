import Foundation

/// Only recognized local actions can open an entry sheet. A draft never saves itself.
struct QuickEntryRequest: Identifiable, Equatable {
    let id = UUID()
    let method: ExpenseInputMethod
    var title: String = ""
    var amount: Double? = nil

    init?(url: URL) {
        guard url.scheme == "bagidooit", url.path.isEmpty || url.path == "/",
              let host = url.host else { return nil }
        switch host {
        case "scan": method = .receiptScanner
        case "voice": method = .voice
        case "expense": method = .manual
        default: return nil
        }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if method == .manual {
            guard let name = query.first(where: { $0.name == "title" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty, name.count <= 120,
                  let raw = query.first(where: { $0.name == "amount" })?.value,
                  let value = Double(raw), value.isFinite, value > 0, value <= 1_000_000_000 else { return nil }
            title = name
            amount = value
        }
    }
}
