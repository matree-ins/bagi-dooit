import AppIntents
import Foundation

struct RecordExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Catat Pengeluaran"
    static let description = IntentDescription("Isi nominal dalam rupiah dan keterangan, lalu periksa dan simpan di Bagi Dooit.")

    @Parameter(title: "Nominal dalam rupiah", requestValueDialog: "Berapa rupiah pengeluarannya?")
    var amount: Double

    @Parameter(title: "Keterangan", requestValueDialog: "Untuk pengeluaran apa?")
    var expenseTitle: String

    func perform() async throws -> some IntentResult & OpensIntent {
        guard amount.isFinite, amount > 0, amount <= 1_000_000_000 else {
            throw $amount.needsValueError("Masukkan nominal di atas nol, maksimal satu miliar rupiah.")
        }
        let name = expenseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 120 else {
            throw $expenseTitle.needsValueError("Isi keterangan dengan satu sampai 120 karakter.")
        }
        var components = URLComponents()
        components.scheme = "bagidooit"
        components.host = "expense"
        components.queryItems = [URLQueryItem(name: "title", value: name), URLQueryItem(name: "amount", value: String(amount))]
        return .result(opensIntent: OpenURLIntent(components.url!))
    }
}
