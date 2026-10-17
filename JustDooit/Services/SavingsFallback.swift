import Foundation

@MainActor
enum SavingsFallback {
    static func actions(for advice: FinancialBehaviorAdvice) -> [String] {
        guard advice.threeDayTotal > 0 else {
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
        let budgetTip = advice.status == .alert || advice.status == .warning
            ? "Tunda pembelian yang belum diperlukan dan tinjau anggaran harian."
            : "Pertahankan pencatatan agar pengeluaran tetap terpantau."
        return [categoryTip, budgetTip]
    }
}
