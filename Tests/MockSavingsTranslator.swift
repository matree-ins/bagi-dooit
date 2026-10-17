import Foundation

@MainActor
final class MockSavingsTranslator: SavingsSuggestionTranslating {
    var result = SavingsSuggestion(summary: "Belanja merupakan kategori terbesar yang tercatat.", actions: ["Buat daftar kebutuhan sebelum berbelanja.", "Tinjau pembelian yang belum diperlukan."])
    var failure: Error?
    var prepareFailure: Error?
    var delay: UInt64 = 0
    var prepareCalls = 0
    var translationCalls = 0
    var wasCancelled = false

    func prepare() async throws {
        prepareCalls += 1
        if let prepareFailure { throw prepareFailure }
    }
    func translate(_ source: SavingsSuggestion) async throws -> SavingsSuggestion {
        translationCalls += 1
        if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
        if let failure { throw failure }
        return result
    }
    func cancel() { wasCancelled = true }
}
