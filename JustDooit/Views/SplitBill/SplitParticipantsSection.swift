import SwiftUI

struct SplitParticipantsSection: View {
    @Binding var session: SplitBillSession
    @Binding var showContactPicker: Bool
    @Binding var showAddManualFriendSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Teman yang ikut", systemImage: "person.2.badge.gearshape.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(session.participants.count) Orang")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(BagiTheme.primary.opacity(0.12))
                    .foregroundStyle(BagiTheme.primary)
                    .clipShape(Capsule())
            }

            // Big Action Buttons to Pick from Contacts
            HStack(spacing: 10) {
                Button(action: { showContactPicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.subheadline)
                        Text("Pilih kontak")
                            .font(.footnote)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BagiTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: { showAddManualFriendSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.footnote)
                        Text("Manual")
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(BagiTheme.surface)
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Contact chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(session.participants) { participant in
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(participant.name == "Saya" ? BagiTheme.primary.opacity(0.2) : Color.green.opacity(0.2))
                                    .frame(width: 34, height: 34)
                                Text(participant.name.prefix(1).uppercased())
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .foregroundStyle(participant.name == "Saya" ? BagiTheme.primary : Color.green)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(participant.name)
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    if !participant.phoneNumber.isEmpty {
                                        Image(systemName: "phone.fill")
                                            .font(.system(.footnote))
                                            .foregroundStyle(.green)
                                        Text(participant.phoneNumber)
                                            .font(.system(.footnote))
                                            .foregroundStyle(BagiTheme.muted)
                                            .lineLimit(1)
                                    } else {
                                        Text("(Saya)")
                                            .font(.system(.footnote))
                                            .foregroundStyle(BagiTheme.muted)
                                    }
                                }
                            }

                            if participant.name != "Saya" {
                                Button(action: {
                                    session.participants.removeAll { $0.id == participant.id }
                                    for index in session.items.indices {
                                        session.items[index].assignedParticipantIds.remove(participant.id)
                                    }
                                }) {
                                    Label("Hapus \(participant.name) dari tagihan", systemImage: "xmark.circle.fill")
                                        .labelStyle(.iconOnly)
                                        .frame(minWidth: 44, minHeight: 44)
                                        .font(.footnote)
                                        .foregroundStyle(.gray.opacity(0.7))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(BagiTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(participant.phoneNumber.isEmpty ? Color.clear : Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    
    }
}
