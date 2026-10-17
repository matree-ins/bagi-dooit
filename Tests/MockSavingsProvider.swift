import Foundation

@MainActor
final class MockSavingsProvider: SavingsSuggestionProviding {
    var usesEnglish = false
    var availabilityIssue: String?
    var availabilityCanRetry = true
    var failure: Error?
    var response = SavingsSuggestion(summary: "Belanja mendominasi catatan pengeluaran.", actions: ["Periksa daftar kebutuhan sebelum berbelanja.", "Tunda pembelian yang belum diperlukan."])
    var shouldFail = false
    var delay: UInt64 = 0
    var calls = 0

    func generate(for advice: FinancialBehaviorAdvice) async throws -> SavingsSuggestion {
        calls += 1
        let captured = response
        if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
        if let failure { throw failure }
        if shouldFail { throw NSError(domain: "Mock", code: 1) }
        return captured
    }
}
