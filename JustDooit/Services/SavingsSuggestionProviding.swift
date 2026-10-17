import Foundation

@MainActor
protocol SavingsSuggestionProviding {
    var usesEnglish: Bool { get }
    var availabilityCanRetry: Bool { get }
    var availabilityIssue: String? { get }
    func generate(for advice: FinancialBehaviorAdvice) async throws -> SavingsSuggestion
}

extension SavingsSuggestionProviding {
    var usesEnglish: Bool { false }
    var availabilityCanRetry: Bool { true }
}
