import Foundation

enum SiriEntryError: LocalizedError {
    case invalidAmount
    case invalidTitle
    case invalidParticipants
    case invalidItems
    case invalidCharges
    case invalidAssignments
    case invalidBill

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Sebutkan nominal rupiah utuh di atas nol, maksimal satu miliar rupiah."
        case .invalidTitle:
            return "Sebutkan nama tagihan atau keterangan dengan satu sampai 120 karakter."
        case .invalidParticipants:
            return "Sebutkan satu sampai sembilan nama teman yang berbeda, pisahkan dengan koma atau kata dan. Kamu otomatis ikut sebagai Saya."
        case .invalidItems:
            return "Sebutkan setiap item dengan format nama, jumlah, harga satuan. Contoh: nasi goreng jumlah dua harga satuan dua puluh lima ribu. Pisahkan item dengan kata lalu. Gunakan nama item berbeda."
        case .invalidCharges:
            return "Sebutkan nama biaya dan nominal atau persen. Contoh: pajak sepuluh persen lalu ongkir dua belas ribu. Katakan tidak ada jika tanpa tambahan. Diskon tidak boleh melebihi subtotal."
        case .invalidAssignments:
            return "Sebutkan setiap item untuk siapa. Contoh: nasi goreng untuk Budi satu dan Siti satu. Jumlahnya harus sesuai pesanan. Untuk berbagi satu item, sebutkan nama tanpa jumlah."
        case .invalidBill:
            return "Tagihan belum dapat disimpan. Periksa peserta dan nominal, lalu coba lagi."
        }
    }
}
