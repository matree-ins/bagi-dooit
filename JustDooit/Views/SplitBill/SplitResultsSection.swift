import SwiftUI

struct SplitResultsSection: View {
    let session: SplitBillSession
    let onSend: (SplitParticipant) -> Void
    let onPreview: (SplitParticipant) -> Void
    var onTogglePaid: ((SplitParticipant) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "phone.bubble.left.fill")
                        .foregroundStyle(.green)
                    Text("Rincian & Tagihan WA")
                        .font(.headline)
                }
                Spacer()

                // Payment progress badge
                let otherCount = session.participants.filter { $0.name != "Saya" }.count
                if otherCount > 0 {
                    let paidCount = session.participants.filter { $0.name != "Saya" && $0.isPaid }.count
                    HStack(spacing: 4) {
                        Image(systemName: paidCount == otherCount ? "checkmark.circle.fill" : "clock.arrow.circlepath")
                            .font(.caption)
                        Text("\(paidCount)/\(otherCount) Lunas")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(paidCount == otherCount ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundStyle(paidCount == otherCount ? .green : .orange)
                    .clipShape(Capsule())
                }
            }

            Text("Tagih ke WhatsApp dan tandai status pembayaran teman.")
                .font(.footnote)
                .foregroundStyle(BagiTheme.muted)

            if let issue = session.sharingIssue {
                Label(issue, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(BagiTheme.muted)
                    .accessibilityIdentifier("split.validation")
            }

            VStack(spacing: 12) {
                ForEach(session.participants) { participant in
                    let shareTotal = session.participantTotal(for: participant.id)
                    let assignedItems = session.items.filter { $0.assignedParticipantIds.contains(participant.id) }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            ZStack {
                                Circle()
                                    .fill(participant.name == "Saya" ? BagiTheme.primary.opacity(0.15) : (participant.isPaid ? Color.green.opacity(0.15) : Color.orange.opacity(0.15)))
                                    .frame(width: 40, height: 40)
                                Text(participant.name.prefix(1).uppercased())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(participant.name == "Saya" ? BagiTheme.action : (participant.isPaid ? Color.green : Color.orange))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(participant.name)
                                        .font(.subheadline)
                                        .fontWeight(.bold)

                                    if participant.name != "Saya" {
                                        Text(participant.isPaid ? "Lunas" : "Belum Bayar")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(participant.isPaid ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                            .foregroundStyle(participant.isPaid ? .green : .orange)
                                            .clipShape(Capsule())
                                    }
                                }

                                if !participant.phoneNumber.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "phone.fill")
                                            .font(.system(.footnote))
                                            .foregroundStyle(.green)
                                        Text(participant.phoneNumber)
                                            .font(.footnote)
                                            .foregroundStyle(BagiTheme.muted)
                                    }
                                } else {
                                    Text(participant.name == "Saya" ? "Porsi Kamu" : "Kontak Manual")
                                        .font(.footnote)
                                        .foregroundStyle(BagiTheme.muted)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Bagian tagihan")
                                    .font(.system(.footnote))
                                    .foregroundStyle(BagiTheme.muted)
                                Text(CurrencyFormatter.format(shareTotal))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(BagiTheme.primary)
                            }
                        }

                        // List of items assigned to this participant
                        if !assignedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(assignedItems) { item in
                                    let splitCount = max(1, item.assignedParticipantIds.count)
                                    let portionPrice = item.totalPrice / Double(splitCount)
                                    let qtyStr = item.quantity > 1 ? "\(item.quantity)x " : ""
                                    HStack {
                                        Text("• \(qtyStr)\(item.name)" + (splitCount > 1 ? " (\(splitCount) org)" : ""))
                                            .font(.footnote)
                                            .foregroundStyle(BagiTheme.muted)
                                        Spacer()
                                        Text(CurrencyFormatter.format(portionPrice))
                                            .font(.footnote)
                                            .foregroundStyle(BagiTheme.muted)
                                    }
                                }
                            }
                            .padding(10)
                            .background(BagiTheme.soft)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Action Buttons: Tagih WA & Toggle Status Bayar
                        if participant.name != "Saya" {
                            HStack(spacing: 8) {
                                // Status Toggle Button
                                Button(action: {
                                    onTogglePaid?(participant)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: participant.isPaid ? "checkmark.circle.fill" : "circle.dashed")
                                        Text(participant.isPaid ? "Sudah Bayar" : "Tandai Lunas")
                                    }
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(participant.isPaid ? Color.green : Color.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(participant.isPaid ? Color.green.opacity(0.12) : BagiTheme.soft)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Spacer()

                                // Tagih WA Button
                                Button(action: {
                                    onSend(participant)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "paperplane.fill")
                                        Text("Tagih ke WA")
                                    }
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .disabled(!session.canShare)

                                // Preview button
                                Button(action: {
                                    onPreview(participant)
                                }) {
                                    Image(systemName: "eye.fill")
                                        .font(.footnote)
                                        .foregroundStyle(BagiTheme.primary)
                                        .padding(8)
                                        .background(BagiTheme.primary.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(BagiTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
                }
            }
        }
    }
}
