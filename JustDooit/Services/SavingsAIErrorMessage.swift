import Foundation
import FoundationModels

@MainActor
enum SavingsAIErrorMessage {
    static func notice(for error: Error) -> SavingsErrorNotice {
        if let network = error as? URLError {
            switch network.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                return SavingsErrorNotice(message: "Koneksi terputus saat menyiapkan AI. Sambungkan internet untuk menyelesaikan persiapannya. Saran bawaan tetap tersedia.")
            case .timedOut:
                return SavingsErrorNotice(message: "Menyiapkan saran terlalu lama. Coba lagi sebentar; saran bawaan tetap tersedia.")
            case .cancelled:
                return SavingsErrorNotice(message: "Pembuatan saran terhenti. Saran bawaan tetap tersedia.")
            default: break
            }
        }
        if error is SystemLanguageModel.Error {
            return SavingsErrorNotice(message: "AI di perangkat belum siap digunakan. Periksa Apple Intelligence di Pengaturan dan sambungkan internet jika model masih diunduh. Saran bawaan tetap tersedia.")
        }
        if let modelError = error as? LanguageModelError {
            switch modelError {
            case .unsupportedLanguageOrLocale:
                return SavingsErrorNotice(message: "Bahasa saran AI belum didukung. Saran bawaan tetap ditampilkan.", canRetry: false)
            case .timeout:
                return SavingsErrorNotice(message: "Menyiapkan saran terlalu lama. Coba lagi sebentar; saran bawaan tetap tersedia.")
            case .contextSizeExceeded, .unsupportedCapability, .unsupportedTranscriptContent, .unsupportedGenerationGuide:
                return SavingsErrorNotice(message: "AI belum bisa mengolah ringkasan pengeluaran ini. Saran bawaan tetap ditampilkan.", canRetry: false)
            case .rateLimited:
                return SavingsErrorNotice(message: "AI sedang sibuk. Coba lagi sebentar; saran bawaan tetap tersedia.")
            case .guardrailViolation, .refusal:
                return SavingsErrorNotice(message: "AI belum bisa membuat saran dari catatan ini. Saran bawaan tetap ditampilkan.", canRetry: false)
            default: break
            }
        }
        return SavingsErrorNotice(message: "Saran AI belum berhasil dibuat. Coba lagi sebentar; saran bawaan tetap tersedia.")
    }
}
