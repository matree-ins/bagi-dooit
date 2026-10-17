import SwiftUI

struct SavingsTranslationModifier: ViewModifier {
    let service: SavingsAIService

    func body(content: Content) -> some View {
        content.background {
            if let request = service.translationRequest {
                SavingsTranslationTaskView(service: service, requestID: request.id)
                    .id(request.id)
            }
        }
    }
}
