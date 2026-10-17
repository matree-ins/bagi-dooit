//
//  SplitBillView.swift
//  JustDooit
//

import SwiftUI
import UIKit

struct SplitBillView: View {
    @Environment(\.dismiss) private var dismiss
    var expenseStore: ExpenseStore?
    var onComplete: (() -> Void)? = nil
    var onBack: (() -> Void)? = nil
    var isDetailMode: Bool = false

    @State private var session: SplitBillSession

    enum SplitStep: Int, CaseIterable {
        case selectParticipants = 1
        case assignItems = 2
        case summaryShare = 3
    }

    @State private var currentStep: SplitStep
    @State private var showDeleteConfirmation: Bool = false

    init(expenseStore: ExpenseStore? = nil, initialSession: SplitBillSession? = nil, onComplete: (() -> Void)? = nil, onBack: (() -> Void)? = nil, isDetailMode: Bool = false) {
        self.expenseStore = expenseStore
        self.onComplete = onComplete
        self.onBack = onBack
        self.isDetailMode = isDetailMode
        _currentStep = State(initialValue: isDetailMode ? .summaryShare : .selectParticipants)
        _session = State(initialValue: initialSession ?? SplitBillSession(
            title: "Makan Siang Bareng Tim",
            participants: [
                SplitParticipant(name: "Saya", phoneNumber: ""),
                SplitParticipant(name: "Budi Santoso", phoneNumber: "081234567890"),
                SplitParticipant(name: "Siti Rahma", phoneNumber: "085712345678")
            ],
            items: [
                SplitItem(name: "Ayam Bakar Madu", price: 42_000, quantity: 1, assignedParticipantIds: []),
                SplitItem(name: "Es Teh Manis", price: 8_000, quantity: 1, assignedParticipantIds: []),
                SplitItem(name: "Tempe Mendoan (Sharing)", price: 15_000, quantity: 1, assignedParticipantIds: [])
            ]
        ))
    }

    @State private var didAssignDemoItems = false
    @State private var showContactPicker: Bool = false
    @State private var showAddManualFriendSheet: Bool = false
    @State private var showAddItemSheet: Bool = false
    @State private var showReceiptScannerSheet: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var shareText: String = ""

    // Message preview sheet
    @State private var previewParticipant: SplitParticipant? = nil

    // Manual friend state
    @State private var newFriendName: String = ""
    @State private var newFriendPhone: String = ""

    // Manual item state
    @State private var newItemName: String = ""
    @State private var newItemPrice: String = ""
    @State private var newItemQty: Int = 1

    private func formatRp(_ amount: Double) -> String {
        CurrencyFormatter.format(amount).replacingOccurrences(of: " ", with: "")
    }

    var body: some View {
        ZStack {
                Color(hex: "#F6F7FB")
                    .ignoresSafeArea()

                switch currentStep {
                case .selectParticipants:
                    selectParticipantsView
                case .assignItems:
                    assignItemsView
                case .summaryShare:
                    summaryShareView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isDetailMode {
                        Button("Tutup") {
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#2D50FF"))
                    } else {
                        Button(action: handleBackNavigation) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Kembali")
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "#2D50FF"))
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isDetailMode {
                        Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                                .foregroundStyle(.red)
                        }
                    } else {
                        Text("Langkah \(currentStep.rawValue)/3")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "#6B7280"))
                    }
                }
            }
            .alert("Hapus Tagihan?", isPresented: $showDeleteConfirmation) {
                Button("Batal", role: .cancel) {}
                Button("Hapus Tagihan", role: .destructive) {
                    expenseStore?.deleteSplitSession(id: session.id)
                    dismiss()
                }
            } message: {
                Text("Tagihan ini akan dihapus dari daftar. Anda dapat membuat tagihan baru jika ada salah pembagian.")
            }
            .background(
                ContactPickerPresenter(
                    isPresented: $showContactPicker,
                    onSelectContact: { name, phone in
                        let participant = SplitParticipant(name: name, phoneNumber: phone)
                        session.participants.append(participant)
                    }
                )
            )
            .sheet(isPresented: $showAddManualFriendSheet) {
                manualFriendSheet
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAddItemSheet) {
                manualItemSheet
            }
            .sheet(isPresented: $showReceiptScannerSheet) {
                receiptScannerForSplitBillSheet
            }
            .sheet(item: $previewParticipant) { participant in
                whatsAppPreviewSheet(for: participant)
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(activityItems: [shareText])
            }
    }

    private func handleBackNavigation() {
        switch currentStep {
        case .selectParticipants:
            if let onBack = onBack {
                onBack()
            } else {
                dismiss()
            }
        case .assignItems:
            currentStep = .selectParticipants
        case .summaryShare:
            currentStep = .assignItems
        }
    }

    private func saveSessionToStore() {
        expenseStore?.addSplitSession(session)
    }



    // MARK: - STEP 1: SELECT PARTICIPANTS ("Pilih peserta." matching "Sudah terbaca" design)
    private var selectParticipantsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header: "Pilih peserta." & "Tentukan siapa saja yang ikut patungan."
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pilih peserta.")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color(hex: "#111827"))

                        Text("Tentukan siapa saja yang ikut patungan.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "#6B7280"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Card: Action buttons + Participant Rows + Summary
                    VStack(spacing: 0) {
                        // Action Buttons: Dari Kontak & Input Manual
                        HStack(spacing: 12) {
                            Button(action: { showContactPicker = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Dari Kontak")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(Color(hex: "#2D50FF"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color(hex: "#2D50FF").opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button(action: { showAddManualFriendSheet = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Input Manual")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(Color(hex: "#1F2937"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color(hex: "#F3F4F6"))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 12)

                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 6)

                        // List of Participants
                        VStack(spacing: 10) {
                            ForEach(session.participants.indices, id: \.self) { idx in
                                let participant = session.participants[idx]
                                HStack(spacing: 12) {
                                    // Avatar
                                    ZStack {
                                        Circle()
                                            .fill(participant.name == "Saya" ? Color(hex: "#2D50FF").opacity(0.12) : Color.green.opacity(0.15))
                                            .frame(width: 38, height: 38)
                                        Text(participant.name.prefix(1).uppercased())
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(participant.name == "Saya" ? Color(hex: "#2D50FF") : Color.green)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(participant.name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#111827"))

                                            if participant.name == "Saya" {
                                                Text("Anda")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(Color(hex: "#2D50FF"))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color(hex: "#2D50FF").opacity(0.1))
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        Text(participant.phoneNumber.isEmpty ? (participant.name == "Saya" ? "Pemilik Tagihan" : "Tanpa nomor") : participant.phoneNumber)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color(hex: "#6B7280"))
                                    }

                                    Spacer()

                                    if participant.name != "Saya" {
                                        Button(action: {
                                            let removedId = participant.id
                                            session.participants.removeAll { $0.id == removedId }
                                            for itemIdx in session.items.indices {
                                                session.items[itemIdx].assignedParticipantIds.remove(removedId)
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 14))
                                                .foregroundStyle(Color.red.opacity(0.75))
                                                .frame(width: 32, height: 32)
                                                .background(Color.red.opacity(0.08))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)

                                if idx < session.participants.count - 1 {
                                    Divider()
                                        .opacity(0.3)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)

                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)

                        // Summary: Total Peserta
                        HStack {
                            Text("Total Peserta")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(hex: "#374151"))
                            Spacer()
                            Text("\(session.participants.count) Orang")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(hex: "#111827"))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }

            // Bottom Action: Lanjut ke Bagi Menu
            VStack(spacing: 8) {
                Button(action: {
                    currentStep = .assignItems
                }) {
                    HStack(spacing: 8) {
                        Text("Lanjut ke Bagi Menu")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(session.participants.count >= 2 ? Color(hex: "#2D50FF") : Color.gray.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(session.participants.count < 2)

                if session.participants.count < 2 {
                    Text("Tambahkan minimal 1 teman untuk membagi tagihan")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(Color(hex: "#F6F7FB"))
        }
    }



    // MARK: - STEP 2: ASSIGN ITEMS ("Bagi menu.")
    private var assignItemsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header: "Bagi menu." & "Ketuk peserta untuk membagi tiap makanan."
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bagi menu.")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color(hex: "#111827"))

                        Text("Ketuk peserta untuk membagi tiap makanan.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "#6B7280"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Card: Items list with participant chips
                    VStack(spacing: 0) {
                        VStack(spacing: 16) {
                            ForEach(session.items.indices, id: \.self) { idx in
                                let item = session.items[idx]
                                VStack(alignment: .leading, spacing: 8) {
                                    // Row Header: Name & Total Price
                                    HStack(alignment: .top) {
                                        Text(item.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color(hex: "#111827"))
                                        Spacer()
                                        Text(formatRp(item.totalPrice))
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color(hex: "#111827"))
                                    }

                                    // Subtitle: Qty x Unit Price
                                    HStack {
                                        Text("\(item.quantity) × \(formatRp(item.price))")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color(hex: "#6B7280"))
                                        Spacer()
                                        if !item.assignedParticipantIds.isEmpty {
                                            let count = item.assignedParticipantIds.count
                                            let perPerson = item.totalPrice / Double(count)
                                            Text("\(count) orang (@ \(formatRp(perPerson)))")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#2D50FF"))
                                        } else {
                                            Text("Pilih peserta di bawah")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Color(hex: "#9CA3AF"))
                                        }
                                    }

                                    // Participants chips selection
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            // "Bagi Rata" Button
                                            Button(action: {
                                                let allIds = Set(session.participants.map { $0.id })
                                                if session.items[idx].assignedParticipantIds == allIds {
                                                    session.items[idx].assignedParticipantIds.removeAll()
                                                } else {
                                                    session.items[idx].assignedParticipantIds = allIds
                                                }
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: session.items[idx].assignedParticipantIds.count == session.participants.count ? "checkmark.circle.fill" : "person.2")
                                                        .font(.system(size: 11))
                                                    Text("Semua")
                                                        .font(.system(size: 12, weight: .semibold))
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(session.items[idx].assignedParticipantIds.count == session.participants.count ? Color(hex: "#2D50FF") : Color(hex: "#F3F4F6"))
                                                .foregroundStyle(session.items[idx].assignedParticipantIds.count == session.participants.count ? .white : Color(hex: "#374151"))
                                                .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)

                                            // Individual Participant Chips
                                            ForEach(session.participants) { participant in
                                                let isAssigned = session.items[idx].assignedParticipantIds.contains(participant.id)
                                                Button(action: {
                                                    if isAssigned {
                                                        session.items[idx].assignedParticipantIds.remove(participant.id)
                                                    } else {
                                                        session.items[idx].assignedParticipantIds.insert(participant.id)
                                                    }
                                                }) {
                                                    HStack(spacing: 4) {
                                                        if isAssigned {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 10, weight: .bold))
                                                        }
                                                        Text(participant.name)
                                                            .font(.system(size: 12, weight: .medium))
                                                    }
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(isAssigned ? Color(hex: "#2D50FF") : Color(hex: "#F3F4F6"))
                                                    .foregroundStyle(isAssigned ? .white : Color(hex: "#374151"))
                                                    .clipShape(Capsule())
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding(.vertical, 4)

                                if idx < session.items.count - 1 {
                                    Divider()
                                        .opacity(0.3)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)

                        // Summary breakdown: Subtotal, Pajak, Layanan, Total
                        VStack(spacing: 12) {
                            HStack {
                                Text("Subtotal")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color(hex: "#374151"))
                                Spacer()
                                Text(formatRp(session.subtotal))
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color(hex: "#111827"))
                            }

                            if session.taxAmount > 0 {
                                HStack {
                                    Text("Pajak (\(Int(session.taxPercentage))%)")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color(hex: "#374151"))
                                    Spacer()
                                    Text(formatRp(session.taxAmount))
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color(hex: "#111827"))
                                }
                            }

                            if session.serviceAmount > 0 {
                                HStack {
                                    Text("Layanan (\(Int(session.servicePercentage))%)")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color(hex: "#374151"))
                                    Spacer()
                                    Text(formatRp(session.serviceAmount))
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color(hex: "#111827"))
                                }
                            }

                            Divider()
                                .padding(.vertical, 4)

                            HStack {
                                Text("Total")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color(hex: "#111827"))
                                Spacer()
                                Text(formatRp(session.total))
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color(hex: "#111827"))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }

            // Bottom Action: Lanjut ke Rincian Patungan
            VStack(spacing: 8) {
                Button(action: {
                    currentStep = .summaryShare
                }) {
                    HStack(spacing: 8) {
                        Text("Lihat Hasil Patungan")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canProceedToSummary ? Color(hex: "#2D50FF") : Color.gray.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canProceedToSummary)

                if !canProceedToSummary {
                    Text("Pastikan setiap makanan sudah dibagikan ke minimal 1 orang")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(Color(hex: "#F6F7FB"))
        }
    }

    private var canProceedToSummary: Bool {
        !session.items.isEmpty && session.items.allSatisfy { !$0.assignedParticipantIds.isEmpty }
    }

    // MARK: - STEP 3: SUMMARY & SHARE ("Hasil patungan.")
    private var summaryShareView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header: "Hasil patungan." & subtitle
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isDetailMode ? (session.title.isEmpty ? "Hasil patungan." : session.title) : "Hasil patungan.")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color(hex: "#111827"))

                        Text(isDetailMode ? "Pantau status pembayaran & kirim rincian via WhatsApp." : "Kirim rincian tagihan via WhatsApp.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "#6B7280"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Card: List of each participant's portion
                    VStack(spacing: 0) {
                        VStack(spacing: 16) {
                            ForEach(session.participants.indices, id: \.self) { idx in
                                let participant = session.participants[idx]
                                let pTotal = session.participantTotal(for: participant.id)

                                VStack(alignment: .leading, spacing: 10) {
                                    // Row Header: Participant Name & Share Total
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(participant.name)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundStyle(Color(hex: "#111827"))

                                                if participant.name == "Saya" {
                                                    Text("Anda")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(Color(hex: "#2D50FF"))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color(hex: "#2D50FF").opacity(0.1))
                                                        .clipShape(Capsule())
                                                }
                                            }

                                            Text(assignedItemsSummary(for: participant))
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color(hex: "#6B7280"))
                                                .lineLimit(2)
                                        }

                                        Spacer()

                                        Text(formatRp(pTotal))
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundStyle(Color(hex: "#111827"))
                                    }

                                    // Action Buttons: WhatsApp & Status Pembayaran
                                    if participant.name != "Saya" {
                                        HStack(spacing: 10) {
                                            // WhatsApp Button
                                            Button(action: {
                                                sendWhatsApp(for: participant)
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "message.fill")
                                                        .font(.system(size: 12))
                                                    Text("Kirim WhatsApp")
                                                        .font(.system(size: 13, weight: .semibold))
                                                }
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color(hex: "#25D366"))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }

                                            // Pratinjau Pesan
                                            Button(action: {
                                                previewParticipant = participant
                                            }) {
                                                Text("Pratinjau")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(Color(hex: "#374151"))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 8)
                                                    .background(Color(hex: "#F3F4F6"))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }

                                            Spacer()

                                            // Paid Status Toggle
                                            Button(action: {
                                                session.togglePaid(for: participant.id)
                                                if isDetailMode {
                                                    expenseStore?.updateSplitSession(session)
                                                }
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: participant.isPaid ? "checkmark.circle.fill" : "clock.fill")
                                                        .font(.system(size: 11))
                                                    Text(participant.isPaid ? "Lunas" : "Belum")
                                                        .font(.system(size: 12, weight: .bold))
                                                }
                                                .foregroundStyle(participant.isPaid ? Color.green : Color.orange)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 6)
                                                .background(participant.isPaid ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                                                .clipShape(Capsule())
                                            }
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                                .padding(.vertical, 4)

                                if idx < session.participants.count - 1 {
                                    Divider()
                                        .opacity(0.3)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)

                        // Grand Total Row
                        HStack {
                            Text("Total Tagihan")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color(hex: "#111827"))
                            Spacer()
                            Text(formatRp(session.total))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color(hex: "#111827"))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }

            // Bottom Action
            VStack(spacing: 10) {
                if isDetailMode {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Selesai")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(hex: "#2D50FF"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Hapus Tagihan")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Button(action: {
                        saveSessionToStore()
                        dismiss()
                        onComplete?()
                    }) {
                        Text("Selesai & Simpan")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(hex: "#2D50FF"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(Color(hex: "#F6F7FB"))
        }
    }

    private func assignedItemsSummary(for participant: SplitParticipant) -> String {
        let assigned = session.items.filter { $0.assignedParticipantIds.contains(participant.id) }
        if assigned.isEmpty { return "Belum ada pesanan" }
        return assigned.map { $0.name }.joined(separator: ", ")
    }

    private func sendWhatsApp(for participant: SplitParticipant) {
        guard session.canShare else { return }
        if let url = session.createWhatsAppURL(for: participant) {
            UIApplication.shared.open(url) { success in
                if !success {
                    self.shareText = self.session.generateWhatsAppMessage(for: participant)
                    self.showShareSheet = true
                }
            }
        } else {
            self.shareText = session.generateWhatsAppMessage(for: participant)
            self.showShareSheet = true
        }
    }

    // WhatsApp Message Preview Sheet
    private func whatsAppPreviewSheet(for participant: SplitParticipant) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.green)
                    Text("Pratinjau pesan")
                        .font(.headline)
                }

                Text("Pesan ini akan otomatis dikirim ke nomor **\(participant.phoneNumber.isEmpty ? "(Tanpa nomor)" : participant.phoneNumber)**:")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#6B7280"))

                ScrollView {
                    Text(session.generateWhatsAppMessage(for: participant))
                        .font(.system(.footnote, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#F3F4F6"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: {
                    previewParticipant = nil
                    sendWhatsApp(for: participant)
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Lanjut ke WhatsApp")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#2D50FF"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .navigationTitle("Pesan untuk \(participant.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { previewParticipant = nil }
                }
            }
        }
    }

    // MARK: - Sub-Sheets
    private var manualFriendSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Informasi Teman")) {
                    TextField("Nama Teman", text: $newFriendName)
                    TextField("Nomor WhatsApp (Contoh: 08123456789)", text: $newFriendPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Tambah Teman")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { showAddManualFriendSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tambah") {
                        if !newFriendName.isEmpty {
                            session.participants.append(SplitParticipant(name: newFriendName, phoneNumber: newFriendPhone))
                            newFriendName = ""
                            newFriendPhone = ""
                            showAddManualFriendSheet = false
                        }
                    }
                    .disabled(newFriendName.isEmpty)
                }
            }
        }
    }

    private var manualItemSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Rincian Item")) {
                    TextField("Nama Item / Menu", text: $newItemName)
                    TextField("Harga Satuan (Rp)", text: $newItemPrice)
                        .keyboardType(.numberPad)
                    Stepper("Kuantitas: \(newItemQty)", value: $newItemQty, in: 1...99)
                }
            }
            .navigationTitle("Tambah Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        newItemQty = 1
                        showAddItemSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tambah") {
                        if let price = Double(newItemPrice), !newItemName.isEmpty {
                            session.items.append(SplitItem(name: newItemName, price: price, quantity: newItemQty))
                            newItemName = ""
                            newItemPrice = ""
                            newItemQty = 1
                            showAddItemSheet = false
                        }
                    }
                    .disabled(newItemName.isEmpty || newItemPrice.isEmpty)
                }
            }
        }
    }

    private var receiptScannerForSplitBillSheet: some View {
        NavigationStack {
            SplitBillReceiptScannerView { scannedItems in
                for item in scannedItems {
                    session.items.append(SplitItem(name: item.name, price: item.price, quantity: item.quantity))
                }
                showReceiptScannerSheet = false
            }
            .navigationTitle("Import dari Struk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { showReceiptScannerSheet = false }
                }
            }
        }
    }
}
