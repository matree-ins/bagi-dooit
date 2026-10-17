import Foundation

@MainActor
enum SavingsFallback {
    static func actions(for advice: FinancialBehaviorAdvice) -> [String] {
        guard advice.totalAmount > 0 else {
            return ["Catat pengeluaran untuk mendapatkan saran yang sesuai kebiasaanmu."]
        }
        let categoryTip: String
        switch advice.topCategory {
        case .food: categoryTip = "Rencanakan makan dan bandingkan pilihan sebelum memesan."
        case .transport: categoryTip = "Gabungkan perjalanan yang searah jika memungkinkan."
        case .shopping: categoryTip = "Buat daftar kebutuhan sebelum berbelanja."
        case .bills: categoryTip = "Periksa rincian tagihan dan langganan yang masih diperlukan."
        case .health: categoryTip = "Rencanakan biaya kesehatan tanpa menunda kebutuhan penting."
        case .entertainment: categoryTip = "Pilih kegiatan hiburan yang sesuai anggaran."
        case .other, nil: categoryTip = "Rapikan kategori pengeluaran agar pola belanja lebih jelas."
        }
        let budgetTip: String
        switch advice.status {
        case .alert:
            budgetTip = "Pengeluaran tercatat jauh di atas anggaran. Prioritaskan kebutuhan penting dan tunda belanja tambahan."
        case .warning:
            budgetTip = "Pengeluaran tercatat melewati anggaran. Tinjau pos yang bisa disesuaikan tanpa mengurangi kebutuhan penting."
        case .normal:
            budgetTip = "Pengeluaran tercatat masih dalam anggaran. Pertahankan batas belanja sebelum menambah pengeluaran."
        case .hemat:
            budgetTip = "Pengeluaran tercatat masih jauh di bawah anggaran. Pertahankan kebiasaan ini tanpa merasa harus menghabiskan sisanya."
        case .insufficientData:
            budgetTip = "Lengkapi catatan sebelum menilai kecukupan anggaran."
        }
        return [categoryTip, budgetTip]
    }
}
