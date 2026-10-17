import Foundation

struct SiriSplitBillDraft {
    let session: SplitBillSession

    init(title: String, items: [SiriReceiptItem], charges: SiriBillCharges,
         participants: [SplitParticipant], assignedItems: [SplitItem], date: Date = .now) throws {
        let cleanTitle = try SiriEntryValidator.title(title)
        let subtotal = items.reduce(0) { $0 + $1.total }
        guard subtotal.isFinite, subtotal > 0, subtotal <= 1_000_000_000,
              abs(assignedItems.reduce(0) { $0 + $1.totalPrice } - subtotal) < 0.001 else { throw SiriEntryError.invalidBill }
        let candidate = SplitBillSession(title: cleanTitle, date: date, participants: participants, items: assignedItems,
                                        taxPercentage: 0, servicePercentage: 0, discount: charges.discount,
                                        additionalCharges: charges.charges, roundsToWholeRupiah: true)
        guard candidate.canShare, candidate.total > 0, candidate.total <= 1_000_000_000 else { throw SiriEntryError.invalidBill }
        session = candidate
    }

    var confirmationSummary: String {
        let itemSummary = session.items.map { item in
            let names = session.participants
                .filter { item.assignedParticipantIds.contains($0.id) }
                .map(\.name)
                .formatted()
            return "\(item.name), \(item.quantity) kali \(CurrencyFormatter.format(item.price)), untuk \(names)"
        }.joined(separator: "; ")
        let extras = (session.additionalCharges ?? []).map {
            "\($0.name) \(CurrencyFormatter.format($0.amount(afterDiscount: max(0, session.subtotal - session.discount))))"
        }.formatted()
        let discount = session.discount > 0 ? " Diskon \(CurrencyFormatter.format(session.discount))." : ""
        let shares = session.participants.map {
            "\($0.name) \(CurrencyFormatter.format(session.participantTotal(for: $0.id)))"
        }.joined(separator: "; ")
        return "\(session.title). \(itemSummary). Tambahan: \(extras.isEmpty ? "tidak ada" : extras), dibagi proporsional pesanan.\(discount) Total \(CurrencyFormatter.format(session.total)). Bagian: \(shares). Simpan?"
    }
}
