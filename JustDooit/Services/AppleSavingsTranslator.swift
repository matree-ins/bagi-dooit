import Foundation
import Translation

@MainActor
struct AppleSavingsTranslator: SavingsSuggestionTranslating {
    let session: TranslationSession

    func prepare() async throws {
        let status = await LanguageAvailability().status(from: Locale.Language(identifier: "en"), to: Locale.Language(identifier: "id"))
        guard status != .unsupported else { throw SavingsTranslationFailure.unsupported }
        // The UI-owned session can ask permission to download language packs.
        try await session.prepareTranslation()
        try Task.checkCancellation()
    }

    func translate(_ source: SavingsSuggestion) async throws -> SavingsSuggestion {
        let texts = [source.summary] + source.actions
        let requests = texts.enumerated().map {
            TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset))
        }
        let responses = try await session.translations(from: requests)
        try Task.checkCancellation()
        guard responses.count == texts.count else { throw SavingsTranslationFailure.invalidResult }
        var translated: [Int: String] = [:]
        for response in responses {
            guard let identifier = response.clientIdentifier, let index = Int(identifier),
                  texts.indices.contains(index), translated[index] == nil,
                  response.targetLanguage.languageCode?.identifier == "id" else {
                throw SavingsTranslationFailure.invalidResult
            }
            let target = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty, target.lowercased() != texts[index].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                throw SavingsTranslationFailure.invalidResult
            }
            translated[index] = target
        }
        guard let summary = translated[0], translated.count == texts.count else { throw SavingsTranslationFailure.invalidResult }
        let result = SavingsSuggestion(summary: summary, actions: source.actions.indices.compactMap { translated[$0 + 1] })
        guard result.isValid else { throw SavingsTranslationFailure.invalidResult }
        return result
    }

    func cancel() { session.cancel() }
}
