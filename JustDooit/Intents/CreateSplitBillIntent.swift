import AppIntents
import Foundation

struct CreateSplitBillIntent: AppIntent {
    static let title: LocalizedStringResource = "Buat Split Bill"
    static let description = IntentDescription(
        "Catat split bill ke Bagi Dooit: item, jumlah, harga satuan, pajak/ongkir, nama teman, dan pembagian. Konfirmasi lalu langsung simpan di aplikasi.",
        categoryName: "Split Bill",
        searchKeywords: ["split bill", "bagi tagihan", "patungan", "tagihan", "bill"]
    )
    static let supportedModes: IntentModes = .background
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    // Siri transcribes answers in its own language (English), so prompts show the English grammar the parser accepts.
    @Parameter(title: "Nama tagihan", requestValueDialog: "What is the bill name? For example, lunch.")
    var billTitle: String

    @Parameter(title: "Item, jumlah, harga satuan", requestValueDialog: "Say each item with quantity and unit price. For example: fried rice quantity two unit price twenty five thousand, then iced tea quantity three unit price five thousand.")
    var itemDetails: String

    @Parameter(title: "Pajak, ongkir, tambahan, atau diskon", requestValueDialog: "Any tax, delivery, extra fee, or discount? For example: tax ten percent, then delivery twelve thousand. Say none if there are no extras.")
    var extraDetails: String

    @Parameter(title: "Nama teman", requestValueDialog: "Who joined? You are included automatically. For example: Budi and Siti.")
    var participantNames: String

    @Parameter(title: "Pembagian item", requestValueDialog: "Say who each item is for. For example: fried rice for Budi one and Siti one, then iced tea for me one and Budi one and Siti one. To share one item, say the names without a number.")
    var itemAssignments: String

    static var parameterSummary: some ParameterSummary {
        Summary("Buat \(\.$billTitle) dengan \(\.$itemDetails), tambahan \(\.$extraDetails), peserta \(\.$participantNames), pembagian \(\.$itemAssignments)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do { _ = try SiriEntryValidator.title(billTitle) }
        catch { throw $billTitle.needsValueError("\(error.localizedDescription)") }
        let items: [SiriReceiptItem]
        do { items = try await SiriBillReader.items(itemDetails) }
        catch { throw $itemDetails.needsValueError("\(SiriEntryError.invalidItems.localizedDescription)") }
        let charges: SiriBillCharges
        do { charges = try await SiriBillReader.charges(extraDetails, subtotal: items.reduce(0) { $0 + $1.total }) }
        catch { throw $extraDetails.needsValueError("\(SiriEntryError.invalidCharges.localizedDescription)") }
        let people: [SplitParticipant]
        do { people = try SiriEntryValidator.participants(participantNames) }
        catch { throw $participantNames.needsValueError("\(error.localizedDescription)") }
        let allocations: [SplitItem]
        do { allocations = try await SiriBillReader.assignments(itemAssignments, items: items, participants: people) }
        catch { throw $itemAssignments.needsValueError("\(SiriEntryError.invalidAssignments.localizedDescription)") }
        let draft: SiriSplitBillDraft
        do { draft = try SiriSplitBillDraft(title: billTitle, items: items, charges: charges, participants: people, assignedItems: allocations) }
        catch { throw $itemDetails.needsValueError("The total must be above zero and at most one billion rupiah, including extras. Please say the items again.") }
        try await SiriRecordingService.recordSplitBill(draft, store: ExpenseStore.shared) {
            try await requestConfirmation(actionName: .create, dialog: "\(draft.confirmationSummary)")
        }
        return .result(dialog: "Split bill \(draft.session.title) untuk \(draft.session.participants.count) orang sudah disimpan. Total \(CurrencyFormatter.format(draft.session.total)). Lihat di Beranda Bagi Dooit.")
    }
}
