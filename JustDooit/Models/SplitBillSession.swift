import Foundation

struct SplitBillSession: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var date: Date = Date()
    var participants: [SplitParticipant] = []
    var items: [SplitItem] = []
    var taxPercentage: Double = 11.0 // PPN 11% Indonesia
    var servicePercentage: Double = 5.0
    var discount: Double = 0.0
    // Optional fields preserve decoding of receipts saved before Siri item-level splitting.
    var additionalCharges: [SplitBillCharge]? = nil
    var roundsToWholeRupiah: Bool? = nil

    var subtotal: Double {
        items.reduce(0) { $0 + $1.totalPrice }
    }

    var taxAmount: Double {
        max(0, (subtotal - discount) * (taxPercentage / 100.0))
    }

    var serviceAmount: Double {
        max(0, (subtotal - discount) * (servicePercentage / 100.0))
    }

    var additionalChargesTotal: Double {
        (additionalCharges ?? []).reduce(0) { $0 + $1.amount(afterDiscount: max(0, subtotal - discount)) }
    }

    var total: Double {
        max(0, subtotal - discount + taxAmount + serviceAmount + additionalChargesTotal)
    }

    var paidCount: Int {
        participants.filter { $0.isPaid }.count
    }

    var unpaidCount: Int {
        participants.filter { !$0.isPaid && $0.name != "Saya" }.count
    }

    var isAllPaid: Bool {
        let otherParticipants = participants.filter { $0.name != "Saya" }
        return !otherParticipants.isEmpty && otherParticipants.allSatisfy { $0.isPaid }
    }

    mutating func togglePaid(for participantId: UUID) {
        if let idx = participants.firstIndex(where: { $0.id == participantId }) {
            participants[idx].isPaid.toggle()
        }
    }

    var sharingIssue: String? {
        guard !participants.isEmpty else { return "Tambahkan teman sebelum membagikan tagihan." }
        guard !items.isEmpty else { return "Tambahkan pesanan sebelum membagikan tagihan." }
        let participantIDs = Set(participants.map(\.id))
        guard participantIDs.count == participants.count else { return "Periksa daftar peserta tagihan." }
        guard items.allSatisfy({ !$0.assignedParticipantIds.isEmpty && $0.assignedParticipantIds.isSubset(of: participantIDs) }) else {
            return "Pilih penerima untuk setiap pesanan sebelum membagikan tagihan."
        }
        guard items.allSatisfy({ $0.price.isFinite && $0.price >= 0 }),
              subtotal.isFinite, subtotal > 0,
              discount.isFinite, discount >= 0, discount <= subtotal,
              taxPercentage.isFinite, taxPercentage >= 0,
              servicePercentage.isFinite, servicePercentage >= 0, total.isFinite else {
            return "Periksa nominal pesanan, diskon, pajak, dan layanan."
        }
        guard (additionalCharges ?? []).allSatisfy({
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.value.isFinite && $0.value >= 0
                && ($0.kind != .percentage || $0.value <= 100)
        }) else { return "Periksa biaya tambahan tagihan." }
        return nil
    }

    var canShare: Bool { sharingIssue == nil }

    // Calculates share for an individual participant
    func participantSubtotal(for participantId: UUID) -> Double {
        var sum: Double = 0
        for item in items {
            if item.assignedParticipantIds.contains(participantId) {
                let shareCount = max(1, item.assignedParticipantIds.count)
                sum += item.totalPrice / Double(shareCount)
            }
        }
        return sum
    }

    private func unroundedParticipantTotal(for participantId: UUID) -> Double {
        let pSubtotal = participantSubtotal(for: participantId)
        guard subtotal > 0 else { return 0 }
        let ratio = pSubtotal / subtotal
        let pTax = taxAmount * ratio
        let pService = serviceAmount * ratio
        let pDiscount = discount * ratio
        return max(0, pSubtotal - pDiscount + pTax + pService + additionalChargesTotal * ratio)
    }

    func participantTotal(for participantId: UUID) -> Double {
        guard roundsToWholeRupiah == true else { return unroundedParticipantTotal(for: participantId) }
        guard let index = participants.firstIndex(where: { $0.id == participantId }), total.isFinite else { return 0 }
        let amounts = participants.map { unroundedParticipantTotal(for: $0.id) }
        guard amounts.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return 0 }
        let floors = amounts.map { floor($0) }
        let remainder = Int(max(0, min(Double(participants.count), total.rounded() - floors.reduce(0, +))))
        let priority = participants.indices.sorted {
            let firstFraction = amounts[$0] - floors[$0]
            let secondFraction = amounts[$1] - floors[$1]
            return abs(firstFraction - secondFraction) < 0.000001 ? $0 < $1 : firstFraction > secondFraction
        }
        return floors[index] + (priority.prefix(remainder).contains(index) ? 1 : 0)
    }

    // Generate formatted WhatsApp message
    func generateWhatsAppMessage(for participant: SplitParticipant) -> String {
        let pTotal = participantTotal(for: participant.id)
        let assignedItems = items.filter { $0.assignedParticipantIds.contains(participant.id) }

        var message = """
        🧾 *Split Bill: \(title.isEmpty ? "Makan Bersama" : title)*
        Halo \(participant.name)! 👋
        Berikut rincian tagihan kamu:

        """

        for item in assignedItems {
            let splitAmong = item.assignedParticipantIds.count
            let sharePrice = item.totalPrice / Double(max(1, splitAmong))
            let qtyStr = item.quantity > 1 ? "\(item.quantity)x " : ""
            if splitAmong > 1 {
                message += "• \(qtyStr)\(item.name): \(CurrencyFormatter.format(sharePrice)) (patungan \(splitAmong) orang)\n"
            } else {
                message += "• \(qtyStr)\(item.name): \(CurrencyFormatter.format(sharePrice))\n"
            }
        }

        if discount > 0 { message += "\nDiskon tagihan: \(CurrencyFormatter.format(discount))\n" }
        for charge in additionalCharges ?? [] {
            message += "\n\(charge.name) tagihan: \(CurrencyFormatter.format(charge.amount(afterDiscount: max(0, subtotal - discount)))) (dibagi proporsional pesanan)\n"
        }
        if roundsToWholeRupiah == true { message += "\nPembulatan rupiah menyesuaikan agar total bagian sama dengan total tagihan.\n" }
        if taxPercentage > 0 || servicePercentage > 0 {
            message += "\n_(Termasuk proporsi Pajak/Service)_\n"
        }

        message += """

        💰 *Total yang harus dibayar: \(CurrencyFormatter.format(pTotal))*

        Terima kasih banyak! 🙏✨
        """

        return message
    }

    func createWhatsAppURL(for participant: SplitParticipant) -> URL? {
        let phone = participant.cleanedPhone
        let text = generateWhatsAppMessage(for: participant)
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        let urlString = "https://wa.me/\(phone)?text=\(encodedText)"
        return URL(string: urlString)
    }
}
