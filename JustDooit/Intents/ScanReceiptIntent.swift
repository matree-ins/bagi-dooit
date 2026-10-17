import AppIntents
import Foundation

struct ScanReceiptIntent: AppIntent {
    static let title: LocalizedStringResource = "Foto Struk"
    static let description = IntentDescription("Buka pemindai struk Bagi Dooit.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "bagidooit://scan")!))
    }
}
