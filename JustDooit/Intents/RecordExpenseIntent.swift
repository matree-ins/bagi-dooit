import AppIntents
import Foundation

struct RecordExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Catat Pengeluaran"
    static let description = IntentDescription("Sebutkan nominal dan keterangan. Siri meminta konfirmasi lalu menyimpan pengeluaran tanpa membuka aplikasi.")
    static let supportedModes: IntentModes = .background
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Nominal dalam rupiah", requestValueDialog: "Berapa rupiah pengeluarannya?")
    var amount: Double

    @Parameter(title: "Keterangan", requestValueDialog: "Untuk pengeluaran apa?")
    var expenseTitle: String

    static var parameterSummary: some ParameterSummary {
        Summary("Catat \(\.$expenseTitle) senilai \(\.$amount) rupiah")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do { _ = try SiriEntryValidator.amount(amount) }
        catch { throw $amount.needsValueError("\(error.localizedDescription)") }
        let name: String
        do { name = try SiriEntryValidator.title(expenseTitle) }
        catch { throw $expenseTitle.needsValueError("\(error.localizedDescription)") }
        let expense = Expense(title: name, amount: amount, category: .other, inputMethod: .voice)
        try await SiriRecordingService.recordExpense(expense, store: ExpenseStore.shared) {
            try await requestConfirmation(actionName: .create,
                                          dialog: "Simpan \(name), \(CurrencyFormatter.format(amount)), sebagai pengeluaran pribadi?")
        }
        return .result(dialog: "\(name), \(CurrencyFormatter.format(amount)), sudah dicatat di Riwayat Bagi Dooit.")
    }
}
