//
//  SplitBillView.swift
//  JustDooit
//

import SwiftUI
import UIKit

struct SplitBillView: View {
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
            .navigationTitle("Split Bill")
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "receipt.fill")
                    .foregroundStyle(.blue)
                TextField("Nama Tagihan / Acara", text: $session.title)
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subtotal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(session.subtotal))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Tagihan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(session.total))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - STEP 1: Contacts
    private var step1ContactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("1. Teman & Kontak HP", systemImage: "person.2.badge.gearshape.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(session.participants.count) Orang")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }

            // Big Action Buttons to Pick from Contacts
            HStack(spacing: 10) {
                Button(action: { showContactPicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.subheadline)
                        Text("Pilih dari Kontak HP")
                            .font(.footnote)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
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
                    .background(Color(UIColor.secondarySystemBackground))
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
                                    .fill(participant.name == "Saya" ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                                    .frame(width: 34, height: 34)
                                Text(participant.name.prefix(1).uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(participant.name == "Saya" ? Color.blue : Color.green)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(participant.name)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    if !participant.phoneNumber.isEmpty {
                                        Image(systemName: "phone.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.green)
                                        Text(participant.phoneNumber)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    } else {
                                        Text("(Saya)")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
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
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.gray.opacity(0.7))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
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

    // MARK: - STEP 2: Items & Assignment
    private var step2ItemsAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("2. Assign Item ke Teman", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()

                HStack(spacing: 8) {
                    Button(action: { showReceiptScannerSheet = true }) {
                        Label("Scan Struk", systemImage: "camera.viewfinder")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                    }

                    Button(action: { showAddItemSheet = true }) {
                        Label("Tambah", systemImage: "plus")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Text("Pilih siapa saja teman yang memesan setiap item. Jika pesanan dinikmati bersama, pilih beberapa orang untuk dibagi rata.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if session.items.isEmpty {
                VStack(spacing: 8) {
                    Text("Belum ada item ditambahkan.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("+ Tambah Item Pertama") {
                        showAddItemSheet = true
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 12) {
                    ForEach($session.items) { $item in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    let count = item.assignedParticipantIds.count
                                    if count > 0 {
                                        let perPerson = item.price / Double(count)
                                        Text("\(count) orang (@ \(CurrencyFormatter.format(perPerson)))")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Belum di-assign ke siapa pun!")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.red)
                                    }
                                }

                                Spacer()

                                Text(CurrencyFormatter.format(item.price))
                                    .font(.subheadline)
                                    .fontWeight(.bold)

                                Button(action: {
                                    session.items.removeAll { $0.id == item.id }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .padding(.leading, 4)
                            }

                            Divider()

                            // Interactive Participant Badges
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Assign ke:")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)

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
                                                Text("Semua Orang")
                                            }
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(item.assignedParticipantIds.count == session.participants.count ? Color.blue : Color(UIColor.tertiarySystemBackground))
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
                                                        .font(.system(size: 10))
                                                    Text(participant.name)
                                                        .font(.caption2)
                                                        .fontWeight(.medium)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(isAssigned ? Color.green.opacity(0.18) : Color(UIColor.tertiarySystemBackground))
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
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    // MARK: - STEP 3: Tax & Service
    private var taxAndServiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("3. Pajak & Service Charge", systemImage: "percent")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    Text("Pajak / PPN (\(Int(session.taxPercentage))%)")
                        .font(.footnote)
                    Spacer()
                    Text(CurrencyFormatter.format(session.taxAmount))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $session.taxPercentage, in: 0...20, step: 1)

                HStack {
                    Text("Service Charge (\(Int(session.servicePercentage))%)")
                        .font(.footnote)
                    Spacer()
                    Text(CurrencyFormatter.format(session.serviceAmount))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $session.servicePercentage, in: 0...15, step: 1)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - STEP 4: WhatsApp Share Section
    private var step4WhatsAppShareSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "phone.bubble.left.fill")
                        .foregroundStyle(.green)
                    Text("4. Rincian & Kirim ke WhatsApp")
                        .font(.headline)
                }
                Spacer()
            }

            Text("Pilih teman untuk langsung membuka obrolan WhatsApp dengan tagihan rinci otomatis.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(session.participants) { participant in
                    let shareTotal = session.participantTotal(for: participant.id)
                    let assignedItems = session.items.filter { $0.assignedParticipantIds.contains(participant.id) }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            ZStack {
                                Circle()
                                    .fill(participant.name == "Saya" ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Text(participant.name.prefix(1).uppercased())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(participant.name == "Saya" ? Color.blue : Color.green)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(participant.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                if !participant.phoneNumber.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "phone.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.green)
                                        Text(participant.phoneNumber)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Porsi Kamu")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Total Bayar")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(CurrencyFormatter.format(shareTotal))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
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
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(CurrencyFormatter.format(portionPrice))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Action Buttons: Send WA & Preview Message
                        if participant.name != "Saya" {
                            HStack(spacing: 10) {
                                Button(action: {
                                    sendWhatsApp(for: participant)
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
                                        LinearGradient(
                                            colors: [Color.green, Color(red: 0.1, green: 0.7, blue: 0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                                }

                                Button(action: {
                                    self.previewParticipant = participant
                                }) {
                                    Image(systemName: "eye.fill")
                                        .font(.footnote)
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func sendWhatsApp(for participant: SplitParticipant) {
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
                    Text("Pratinjau Pesan WhatsApp")
                        .font(.headline)
                }

                Text("Pesan ini akan otomatis dikirim ke nomor **\(participant.phoneNumber.isEmpty ? "(Tanpa nomor)" : participant.phoneNumber)**:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView {
                    Text(session.generateWhatsAppMessage(for: participant))
                        .font(.system(.footnote, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: {
                    previewParticipant = nil
                    sendWhatsApp(for: participant)
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Buka WhatsApp & Kirim Sekarang")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
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

// Activity View Controller for Fallback Sharing
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Quick Scanner Helper inside Split Bill
struct SplitBillReceiptScannerView: View {
    var onImport: ([ScannedReceiptItem]) -> Void
    @StateObject private var scanner = ReceiptScannerService()

    var body: some View {
        VStack(spacing: 20) {
            Text("Pindai struk untuk mengimpor daftar menu langsung ke Split Bill.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { scanner.loadDemoReceipt() }) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Gunakan Contoh Struk Resto (Demo Cepat)")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            if let result = scanner.scanResult {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hasil OCR: \(result.merchantName)")
                        .font(.headline)

                    ForEach(result.items) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text(CurrencyFormatter.format(item.price))
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                    }

                    Button(action: {
                        onImport(result.items)
                    }) {
                        Text("Import \(result.items.count) Item ke Split Bill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top)
    }
}
