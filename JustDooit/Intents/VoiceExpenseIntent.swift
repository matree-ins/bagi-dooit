import AppIntents
import Foundation

struct VoiceExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Catat lewat Suara"
    static let description = IntentDescription("Buka pencatatan suara Bagi Dooit. Mikrofon mulai setelah Anda menekan rekam.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "bagidooit://voice")!))
    }
}
