import SwiftUI

struct SplitItemsSection: View {
    @Binding var session: SplitBillSession
    @Binding var showReceiptScannerSheet: Bool
    @Binding var showAddItemSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Pesanan & Menu", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()

                HStack(spacing: 8) {
                    Button(action: { showReceiptScannerSheet = true }) {
                        Label("Scan Struk", systemImage: "camera.viewfinder")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                    }

                    Button(action: { showAddItemSheet = true }) {
                        Label("Tambah", systemImage: "plus")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(BagiTheme.primary)
                    }
                }
            }

            Text("Pilih penerima untuk setiap menu. Beberapa orang akan berbagi rata.")
                .font(.footnote)
                .foregroundStyle(BagiTheme.muted)

            if session.items.isEmpty {
                VStack(spacing: 8) {
                    Text("Belum ada menu ditambahkan.")
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                    Button("+ Tambah Menu Pertama") {
                        showAddItemSheet = true
                    }
                    .font(.footnote)
                    .foregroundStyle(BagiTheme.primary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(BagiTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 12) {
                    ForEach($session.items) { $item in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        if item.quantity > 1 {
                                            Text("\(item.quantity)x")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(BagiTheme.primary.opacity(0.15))
                                                .foregroundStyle(BagiTheme.primary)
                                                .clipShape(Capsule())
                                        }
                                        Text(item.name)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }

                                    let count = item.assignedParticipantIds.count
                                    if count > 0 {
                                        let perPerson = item.totalPrice / Double(count)
                                        Text("\(count) orang (@ \(CurrencyFormatter.format(perPerson)))")
                                            .font(.system(.footnote))
                                            .foregroundStyle(BagiTheme.muted)
                                    } else {
                                        Text("Pilih penerima menu ini")
                                            .font(.system(.footnote))
                                            .foregroundStyle(.red)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(CurrencyFormatter.format(item.totalPrice))
                                        .font(.subheadline)
                                        .fontWeight(.bold)

                                    if item.quantity > 1 {
                                        Text("@ \(CurrencyFormatter.format(item.price))")
                                            .font(.caption2)
                                            .foregroundStyle(BagiTheme.muted)
                                    }
                                }

                                Button(action: {
                                    session.items.removeAll { $0.id == item.id }
                                }) {
                                    Label("Hapus \(item.name)", systemImage: "trash")
                                        .labelStyle(.iconOnly)
                                        .frame(minWidth: 36, minHeight: 36)
                                        .font(.footnote)
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .padding(.leading, 4)
                            }

                            Divider()

                            // Interactive Participant Badges
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Dibagi ke")
                                    .font(.system(.footnote, weight: .bold))
                                    .foregroundStyle(BagiTheme.muted)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        // Quick All button
                                        Button(action: {
                                            if item.assignedParticipantIds.count == session.participants.count {
                                                item.assignedParticipantIds.removeAll()
                                            } else {
                                                item.assignedParticipantIds = Set(session.participants.map { $0.id })
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: item.assignedParticipantIds.count == session.participants.count ? "checkmark.circle.fill" : "circle")
                                                Text("Semua")
                                            }
                                            .font(.footnote)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(item.assignedParticipantIds.count == session.participants.count ? BagiTheme.primary : BagiTheme.soft)
                                            .foregroundStyle(item.assignedParticipantIds.count == session.participants.count ? .white : .primary)
                                            .clipShape(Capsule())
                                        }

                                        ForEach(session.participants) { participant in
                                            let isAssigned = item.assignedParticipantIds.contains(participant.id)
                                            Button(action: {
                                                if isAssigned {
                                                    item.assignedParticipantIds.remove(participant.id)
                                                } else {
                                                    item.assignedParticipantIds.insert(participant.id)
                                                }
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: isAssigned ? "checkmark.circle.fill" : "plus.circle")
                                                        .font(.system(.footnote))
                                                    Text(participant.name)
                                                        .font(.footnote)
                                                        .fontWeight(.medium)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 8)
                                                .background(isAssigned ? Color.green.opacity(0.18) : BagiTheme.soft)
                                                .foregroundStyle(isAssigned ? Color.green : Color.primary)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(isAssigned ? Color.green : Color.clear, lineWidth: 1.2)
                                                )
                                                .clipShape(Capsule())
                                            }
                                        }
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
}
