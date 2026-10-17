import SwiftUI
import Translation

/// Each request owns a fresh UI-backed session, so callbacks cannot claim a newer request.
struct SavingsTranslationTaskView: View {
    let service: SavingsAIService
    let requestID: UUID

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .translationTask(source: Locale.Language(identifier: "en"), target: Locale.Language(identifier: "id")) { session in
                await service.translatePending(using: AppleSavingsTranslator(session: session), requestID: requestID)
            }
    }
}
