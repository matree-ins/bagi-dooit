import Foundation
import Translation

@MainActor
enum SavingsTranslationErrorMessage {
    static func notice(for error: Error) -> SavingsErrorNotice? {
        switch error {
        case SavingsTranslationFailure.unsupported, TranslationError.unsupportedSourceLanguage,
             TranslationError.unsupportedTargetLanguage, TranslationError.unsupportedLanguagePairing:
            return nil // Keep Indonesian fallback without a language-support notification.
        case TranslationError.notInstalled:
            return SavingsErrorNotice(message: "Paket bahasa belum tersedia. Sambungkan internet dan izinkan unduhan bahasa saat mencoba lagi. Saran bawaan tetap ditampilkan.")
        case TranslationError.alreadyCancelled:
            return SavingsErrorNotice(message: "Penerjemahan terhenti. Saran bawaan berbahasa Indonesia tetap ditampilkan.")
        case let network as URLError where [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost].contains(network.code):
            return SavingsErrorNotice(message: "Koneksi terputus saat menyiapkan bahasa. Sambungkan internet lalu coba lagi. Saran bawaan tetap ditampilkan.")
        case SavingsTranslationFailure.invalidResult:
            return SavingsErrorNotice(message: "Terjemahan saran belum lengkap. Saran bawaan berbahasa Indonesia tetap ditampilkan.")
        default:
            return SavingsErrorNotice(message: "Saran belum berhasil diterjemahkan. Coba lagi sebentar; saran bawaan berbahasa Indonesia tetap ditampilkan.")
        }
    }
}
