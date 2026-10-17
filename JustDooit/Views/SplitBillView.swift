//
//  SplitBillView.swift
//  JustDooit
//

import SwiftUI
import UIKit

struct SplitBillView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var session = SplitBillSession(
        title: "Makan Siang Bareng Tim",
        participants: [
            SplitParticipant(name: "Saya", phoneNumber: ""),
            SplitParticipant(name: "Budi Santoso", phoneNumber: "081234567890"),
            SplitParticipant(name: "Siti Rahma", phoneNumber: "085712345678")
        ],
        items: [
            SplitItem(name: "Ayam Bakar Madu", price: 42_000, assignedParticipantIds: []),
            SplitItem(name: "Es Teh Manis", price: 8_000, assignedParticipantIds: []),
            SplitItem(name: "Tempe Mendoan (Sharing)", price: 15_000, assignedParticipantIds: [])
        ]
    )

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Banner
                    headerCard

                    // STEP 1: Contacts & Friends Section
                    step1ContactsSection

                    // STEP 2: Item Assignment Section
                    step2ItemsAssignmentSection

                    // STEP 3: Tax & Service Charges
                    taxAndServiceSection

                    // STEP 4: WhatsApp Sender Section
                    step4WhatsAppShareSection
                }
                .padding()
                .padding(.bottom, 40)
            }
            .bagiScreen()
            .navigationTitle("Bagi tagihan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView { name, phone in
                    let participant = SplitParticipant(name: name, phoneNumber: phone)
                    session.participants.append(participant)
                }
            }
            .sheet(isPresented: $showAddManualFriendSheet) {
                manualFriendSheet
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
            .onAppear {
                autoAssignDefaultDemoItems()
            }
        }
    }

    private func autoAssignDefaultDemoItems() {
        guard !didAssignDemoItems else { return }
        didAssignDemoItems = true
        if session.participants.count >= 3 && !session.items.isEmpty {
            if session.items[0].assignedParticipantIds.isEmpty {
                session.items[0].assignedParticipantIds.insert(session.participants[1].id)
            }
            if session.items.count > 1 && session.items[1].assignedParticipantIds.isEmpty {
                session.items[1].assignedParticipantIds.insert(session.participants[2].id)
            }
            if session.items.count > 2 && session.items[2].assignedParticipantIds.isEmpty {
                session.items[2].assignedParticipantIds = Set(session.participants.map { $0.id })
            }
        }
    }

    // MARK: - Header
    private var headerCard: some View {
        SplitBillSummaryCard(session: $session)
    }

    // MARK: - STEP 1: Contacts
    private var step1ContactsSection: some View {
        SplitParticipantsSection(session: $session, showContactPicker: $showContactPicker, showAddManualFriendSheet: $showAddManualFriendSheet)
    }

    // MARK: - STEP 2: Items & Assignment
    private var step2ItemsAssignmentSection: some View {
        SplitItemsSection(session: $session, showReceiptScannerSheet: $showReceiptScannerSheet, showAddItemSheet: $showAddItemSheet)
    }

    // MARK: - STEP 3: Tax & Service
    private var taxAndServiceSection: some View {
        SplitChargesSection(session: $session)
    }

    // MARK: - STEP 4: WhatsApp Share Section
    private var step4WhatsAppShareSection: some View {
        SplitResultsSection(session: session, onSend: { sendWhatsApp(for: $0) }, onPreview: { previewParticipant = $0 })
    }

    private func sendWhatsApp(for participant: SplitParticipant) {
        guard session.canShare else { return }
        if let url = session.createWhatsAppURL(for: participant) {
            UIApplication.shared.open(url) { success in
                if !success {
                    // Fallback to share sheet if opening url failed
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
                    .foregroundStyle(BagiTheme.muted)

                ScrollView {
                    Text(session.generateWhatsAppMessage(for: participant))
                        .font(.system(.footnote, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BagiTheme.surface)
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
                    .background(BagiTheme.primary)
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
                    TextField("Harga (Rp)", text: $newItemPrice)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Tambah Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { showAddItemSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tambah") {
                        if let price = Double(newItemPrice), !newItemName.isEmpty {
                            session.items.append(SplitItem(name: newItemName, price: price))
                            newItemName = ""
                            newItemPrice = ""
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
                    session.items.append(SplitItem(name: item.name, price: item.price))
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
