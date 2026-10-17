import AppIntents
import Foundation

struct CreateSplitBillIntent: AppIntent {
    static let title: LocalizedStringResource = "Buat Split Bill"
    static let description = IntentDescription("Catat item, jumlah, harga satuan, tambahan, dan pembagian ke nama teman lewat Siri. Konfirmasi lalu langsung simpan ke aplikasi.")
    static let supportedModes: IntentModes = .background
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Nama tagihan", requestValueDialog: "Apa nama tagihannya?")
    var billTitle: String

    @Parameter(title: "Item, jumlah, harga satuan", requestValueDialog: "Sebutkan item, jumlah, harga satuan. Contoh nasi goreng jumlah dua harga satuan dua puluh lima ribu, lalu es teh jumlah tiga harga satuan lima ribu.")
    var itemDetails: String

    @Parameter(title: "Pajak, ongkir, tambahan, atau diskon", requestValueDialog: "Ada tambahan atau diskon? Contoh pajak sepuluh persen lalu ongkir dua belas ribu. Biaya dibagi proporsional pesanan. Katakan tidak ada jika tanpa tambahan.")
    var extraDetails: String

    @Parameter(title: "Nama teman", requestValueDialog: "Siapa saja teman yang ikut? Kamu otomatis ikut sebagai Saya. Pisahkan nama dengan koma atau kata dan.")
    var participantNames: String

    @Parameter(title: "Pembagian item", requestValueDialog: "Sebutkan setiap item untuk siapa. Contoh nasi goreng untuk Budi satu dan Siti satu, lalu es teh untuk Saya satu dan Budi satu dan Siti satu. Untuk berbagi satu item, sebutkan nama tanpa jumlah.")
    var itemAssignments: String

    static var parameterSummary: some ParameterSummary {
        Summary("Buat \(\.$billTitle) dengan \(\.$itemDetails), tambahan \(\.$extraDetails), peserta \(\.$participantNames), pembagian \(\.$itemAssignments)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do { _ = try SiriEntryValidator.title(billTitle) }
        catch { throw $billTitle.needsValueError("\(error.localizedDescription)") }
        let items: [SiriReceiptItem]
        do { items = try SiriBillParser.items(itemDetails) }
        catch { throw $itemDetails.needsValueError("\(SiriEntryError.invalidItems.localizedDescription)") }
        let charges: SiriBillCharges
        do { charges = try SiriBillParser.charges(extraDetails, subtotal: items.reduce(0) { $0 + $1.total }) }
        catch { throw $extraDetails.needsValueError("\(SiriEntryError.invalidCharges.localizedDescription)") }
        let people: [SplitParticipant]
        do { people = try SiriEntryValidator.participants(participantNames) }
        catch { throw $participantNames.needsValueError("\(error.localizedDescription)") }
        let allocations: [SplitItem]
        do { allocations = try SiriBillParser.assignments(itemAssignments, items: items, participants: people) }
        catch { throw $itemAssignments.needsValueError("\(SiriEntryError.invalidAssignments.localizedDescription)") }
        let draft: SiriSplitBillDraft
        do { draft = try SiriSplitBillDraft(title: billTitle, items: items, charges: charges, participants: people, assignedItems: allocations) }
        catch { throw $itemDetails.needsValueError("Total harus di atas nol dan maksimal satu miliar rupiah, termasuk biaya. Periksa rincian item dan biaya.") }
        try await SiriRecordingService.recordSplitBill(draft, store: ExpenseStore.shared) {
            try await requestConfirmation(actionName: .create, dialog: "\(draft.confirmationSummary)")
        }
        return .result(dialog: "Split bill \(draft.session.title) untuk \(draft.session.participants.count) orang sudah disimpan. Total \(CurrencyFormatter.format(draft.session.total)). Lihat di Beranda Bagi Dooit.")
    }
}
