import AppIntents
import Foundation

struct VoiceExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Buka Input Suara"
    static let description = IntentDescription("Buka pencatatan suara Bagi Dooit. Mikrofon mulai setelah Anda menekan rekam.")

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = URL(string: "bagidooit://voice") else {
            throw SiriEntryError.invalidBill
        }
        return .result(opensIntent: OpenURLIntent(url))
    }
}
