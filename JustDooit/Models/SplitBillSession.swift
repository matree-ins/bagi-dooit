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

    var subtotal: Double {
        items.reduce(0) { $0 + $1.totalPrice }
    }

    var taxAmount: Double {
        max(0, (subtotal - discount) * (taxPercentage / 100.0))
    }

    var serviceAmount: Double {
        max(0, (subtotal - discount) * (servicePercentage / 100.0))
    }

    var total: Double {
        max(0, subtotal - discount + taxAmount + serviceAmount)
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

    func participantTotal(for participantId: UUID) -> Double {
        let pSubtotal = participantSubtotal(for: participantId)
        guard subtotal > 0 else { return 0 }
        let ratio = pSubtotal / subtotal
        let pTax = taxAmount * ratio
        let pService = serviceAmount * ratio
        let pDiscount = discount * ratio
        return max(0, pSubtotal - pDiscount + pTax + pService)
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
