import Foundation

@MainActor
protocol SavingsSuggestionTranslating {
    func prepare() async throws
    func translate(_ source: SavingsSuggestion) async throws -> SavingsSuggestion
    func cancel()
}
