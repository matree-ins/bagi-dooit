import SwiftUI

struct SplitResultsSection: View {
    let session: SplitBillSession
    let onSend: (SplitParticipant) -> Void
    let onPreview: (SplitParticipant) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "phone.bubble.left.fill")
                        .foregroundStyle(.green)
                    Text("Rincian pembagian")
                        .font(.headline)
                }
                Spacer()
            }

            Text("Periksa rincian sebelum dibagikan.")
                .font(.footnote)
                .foregroundStyle(BagiTheme.muted)

            VStack(spacing: 12) {
                ForEach(session.participants) { participant in
                    let shareTotal = session.participantTotal(for: participant.id)
                    let assignedItems = session.items.filter { $0.assignedParticipantIds.contains(participant.id) }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            ZStack {
                                Circle()
                                    .fill(participant.name == "Saya" ? BagiTheme.primary.opacity(0.15) : Color.green.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Text(participant.name.prefix(1).uppercased())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(participant.name == "Saya" ? BagiTheme.primary : Color.green)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(participant.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
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
                                    Text("Porsi Kamu")
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

                        // List of items assigned to this friend
                        if !assignedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(assignedItems) { item in
                                    let splitCount = max(1, item.assignedParticipantIds.count)
                                    let portionPrice = item.price / Double(splitCount)
                                    HStack {
                                        Text("• \(item.name)" + (splitCount > 1 ? " (\(splitCount) org)" : ""))
                                            .font(.footnote)
                                            .foregroundStyle(BagiTheme.muted)
                                        Spacer()
                                        Text(CurrencyFormatter.format(portionPrice))
                                            .font(.footnote)
                                            .foregroundStyle(BagiTheme.muted)
                                    }
                                }
                            }
                            .padding(8)
                            .background(BagiTheme.soft)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Action Buttons: Send WA & Preview Message
                        if participant.name != "Saya" {
                            HStack(spacing: 10) {
                                Button(action: {
                                    onSend(participant)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "paperplane.fill")
                                        Text("Kirim WA (\(participant.name))")
                                    }
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        BagiTheme.primary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                                }

                                Button(action: {
                                    onPreview(participant)
                                }) {
                                    Image(systemName: "eye.fill")
                                        .font(.footnote)
                                        .foregroundStyle(BagiTheme.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(BagiTheme.primary.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
