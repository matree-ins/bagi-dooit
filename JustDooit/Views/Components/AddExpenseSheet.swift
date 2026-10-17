import SwiftUI
import PhotosUI

struct AddExpenseSheet: View {
    @ObservedObject var expenseStore: ExpenseStore
    @Environment(\.dismiss) private var dismiss

    // Entry Steps
    enum EntryStep {
        case scanReceipt   // Direct viewfinder screen
        case reviewBill    // Review receipt items & totals matching Review receipt.png
        case splitBill     // Select participants & split bill flow
        case manualEntry   // Manual input form
        case voiceEntry    // Voice recognition form
    }

    enum BillMode {
        case personal
        case splitBill
    }

    struct BillItemEntry: Identifiable {
        let id = UUID()
        var name: String
        var price: Double
        var quantity: Int

        var totalPrice: Double {
            price * Double(quantity)
        }
    }

    @State private var currentStep: EntryStep = .scanReceipt
    @State private var billMode: BillMode = .splitBill

    // Bill Header Data
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var category: ExpenseCategory = .food

    // Items list (scanned or entered)
    @State private var items: [BillItemEntry] = []

    // Manual input scratchpad
    @State private var manualItemName: String = ""
    @State private var manualItemPrice: String = ""
    @State private var manualItemQty: Int = 1
    @State private var note: String = ""

    // Correction Sheet State for Review Screen ("Ketuk item untuk mengoreksi")
    @State private var editingItemIndex: Int? = nil
    @State private var editingItemName: String = ""
    @State private var editingItemPrice: String = ""
    @State private var editingItemQty: Int = 1
    @State private var showEditItemSheet: Bool = false

    // Voice Service State
    @StateObject private var speechService = SpeechRecognitionService()

    // Scanner Service State
    @StateObject private var scannerService = ReceiptScannerService()
    @State private var showCameraPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    // Scan Failed Alert State
    @State private var showScanFailedAlert: Bool = false
    @State private var scanFailedMessage: String = ""

    // Split Bill Destination State
    @State private var navigateToSplitBill: Bool = false
    @State private var preparedSession: SplitBillSession? = nil

    private var totalBillAmount: Double {
        items.reduce(0) { $0 + $1.totalPrice }
    }

    private var subtotalAmount: Double {
        items.reduce(0) { $0 + $1.totalPrice }
    }

    private var taxAmount: Double {
        if let res = scannerService.scanResult, res.totalAmount > subtotalAmount {
            let diff = res.totalAmount - subtotalAmount
            // If diff ~10% (Solaria PB1 10%)
            if abs(diff - round(subtotalAmount * 0.10)) <= 25 {
                return diff
            }
            // If diff ~15% (Kedai Senja: 10% tax + 5% service)
            if abs(diff - round(subtotalAmount * 0.15)) <= 50 {
                return round(subtotalAmount * 0.10)
            }
        }
        return round(subtotalAmount * 0.10)
    }

    private var serviceAmount: Double {
        if let res = scannerService.scanResult, res.totalAmount > subtotalAmount {
            let diff = res.totalAmount - subtotalAmount
            // Solaria PB1 only (diff is ~10%)
            if abs(diff - round(subtotalAmount * 0.10)) <= 25 {
                return 0
            }
            // Kedai Senja (15% diff = 10% tax + 5% service)
            if abs(diff - round(subtotalAmount * 0.15)) <= 50 {
                return round(subtotalAmount * 0.05)
            }
            let rem = diff - taxAmount
            if rem > 0 { return rem }
        }
        return round(subtotalAmount * 0.05)
    }

    private var grandTotalAmount: Double {
        if let res = scannerService.scanResult, res.totalAmount >= subtotalAmount {
            return res.totalAmount
        }
        return subtotalAmount + taxAmount + serviceAmount
    }

    private var totalItemsQuantity: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    private func formatRp(_ amount: Double) -> String {
        CurrencyFormatter.format(amount).replacingOccurrences(of: " ", with: "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#F6F7FB")
                    .ignoresSafeArea()

                switch currentStep {
                case .scanReceipt:
                    scanReceiptDirectView
                case .reviewBill:
                    reviewBillView
                case .splitBill:
                    if let session = preparedSession {
                        SplitBillView(
                            expenseStore: expenseStore,
                            initialSession: session,
                            onComplete: { dismiss() },
                            onBack: { currentStep = .reviewBill }
                        )
                    }
                case .manualEntry:
                    manualEntryView
                case .voiceEntry:
                    voiceEntryView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if currentStep != .splitBill {
                    ToolbarItem(placement: .topBarLeading) {
                        if currentStep == .scanReceipt {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.primary)
                            }
                        } else {
                            Button(action: {
                                resetAllInputState()
                                currentStep = .scanReceipt
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Kembali")
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: "#2D50FF"))
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCameraPicker) {
                CameraPickerView(sourceType: .camera) { image in
                    scannerService.processImage(image)
                }
            }
            .sheet(isPresented: $showEditItemSheet) {
                editItemCorrectionSheet
            }
            .alert("Struk Tidak Terdeteksi", isPresented: $showScanFailedAlert) {
                Button("Coba Lagi") {
                    takeReceiptPhoto()
                }
                Button("Input Manual") {
                    resetAllInputState()
                    currentStep = .manualEntry
                }
                Button("Tutup", role: .cancel) {}
            } message: {
                Text(scanFailedMessage.isEmpty
                    ? "Kamera tidak dapat mendeteksi menu atau harga dari foto ini.\n\nTips:\n• Pastikan seluruh bagian nota terlihat jelas\n• Gunakan foto dengan pencahayaan terang\n• Atau gunakan Input Manual jika tidak ada struk fisik.\n\nSilakan coba lagi!"
                    : "\(scanFailedMessage)\n\nSilakan coba lagi dengan foto struk yang lebih tajam atau gunakan Input Manual.")
            }

            .task(id: selectedPhotoItem) {
                guard let item = selectedPhotoItem else { return }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        scannerService.reportImageLoadingError()
                        return
                    }
                    guard !Task.isCancelled else { return }
                    scannerService.processImage(image)
                } catch {
                    guard !Task.isCancelled else { return }
                    scannerService.reportImageLoadingError()
                }
            }
            .onChange(of: scannerService.scanResult) { _, result in
                guard let result = result else { return }
                if result.items.isEmpty {
                    scannerService.errorMessage = "Struk tidak terdeteksi"
                } else {
                    applyReceiptResult(result)
                    currentStep = .reviewBill
                }
            }
            .onChange(of: scannerService.errorMessage) { _, _ in
                // Alert is displayed inline above the 3 option buttons
            }
            .onDisappear {
                speechService.cancelRecording()
            }
        }
    }

    private func resetAllInputState() {
        items = []
        title = ""
        manualItemName = ""
        manualItemPrice = ""
        manualItemQty = 1
        note = ""
        scannerService.scanResult = nil
        speechService.cancelRecording()
    }

    // MARK: - 1. DIRECT SCAN RECEIPT VIEW
    private var scanReceiptDirectView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Title & Subtitle
            VStack(alignment: .leading, spacing: 6) {
                Text("Struknya, sini.")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Posisikan seluruh struk di dalam bingkai.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "#6B7280"))
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)

            // Viewfinder Card (Dark Navy / Midnight Preview)
            receiptViewfinderCard
                .padding(.horizontal, 24)

            // Scanning Status Notice
            if scannerService.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Sedang memindai teks dan menu struk...")
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            }

            Spacer()

            // Error Alert: only "Struk tidak terdeteksi" above the 3 option buttons
            if scannerService.errorMessage != nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 14))

                    Text("Struk tidak terdeteksi")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1F2937"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            // 3 Optional Action Buttons: Galeri, Suara, Manual
            HStack(spacing: 12) {
                // Dari Galeri Button (PhotosPicker)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 13, weight: .medium))
                        Text("Dari Galeri")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "#1F2937"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
                }

                // Suara Button
                Button(action: {
                    resetAllInputState()
                    currentStep = .voiceEntry
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Suara")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "#1F2937"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
                }

                // Input Manual Button
                Button(action: {
                    resetAllInputState()
                    currentStep = .manualEntry
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 13, weight: .medium))
                        Text("Input Manual")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "#1F2937"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Main Action Button: "Ambil Foto Struk" (Below the 3 Optional Buttons)
            Button(action: takeReceiptPhoto) {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Ambil Foto Struk")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "#2D50FF"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(scannerService.isScanning)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // Viewfinder Card (Dark Blue Frame with Ticket)
    private var receiptViewfinderCard: some View {
        ZStack {
            // Dark Midnight Background
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "#0F1A3A"))
                .frame(maxWidth: .infinity)
                .frame(height: 380)

            // Viewfinder Corner Brackets
            CornerBracketsView()
                .stroke(Color.white.opacity(0.85), lineWidth: 3)
                .frame(width: 270, height: 320)

            // Centered Framed Receipt Ticket
            VStack(spacing: 8) {
                // Header
                Text("KEDAI SENJA")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))

                Text("16 Okt 2026 • Meja 04")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.gray)

                Divider()
                    .padding(.vertical, 2)

                // Items with Qty
                VStack(spacing: 5) {
                    receiptPreviewItemRow(qty: "2", name: "Nasi Goreng", price: "60.000")
                    receiptPreviewItemRow(qty: "3", name: "Es Teh", price: "30.000")
                    receiptPreviewItemRow(qty: "1", name: "Kentang", price: "30.000")
                }

                Divider()
                    .padding(.vertical, 2)

                // Total
                HStack {
                    Text("TOTAL")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black)
                    Spacer()
                    Text("Rp138.000")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black)
                }
            }
            .padding(14)
            .frame(width: 215)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)

            // Green Pill: "✓ Seluruh struk terlihat"
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#22C55E"))
                    Text("Seluruh struk terlihat")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: "#1F336F"))
                .clipShape(Capsule())
                .padding(.bottom, 16)
            }
            .frame(height: 380)
        }
    }

    private func receiptPreviewItemRow(qty: String, name: String, price: String) -> some View {
        HStack {
            Text("\(qty) \(name)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.8))
            Spacer()
            Text(price)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.8))
        }
    }

    private func takeReceiptPhoto() {
        scannerService.errorMessage = nil
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCameraPicker = true
        } else {
            // Simulator or Demo Mode: load realistic receipt data matching the viewfinder ticket
            scannerService.loadKedaiSenjaReceipt()
        }
    }

    // MARK: - 2. REVIEW BILL STEP (Design matching Review receipt.png)
    private var reviewBillView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header: "Sudah terbaca." & "Ketuk item untuk mengoreksi."
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sudah terbaca.")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color(hex: "#111827"))

                        Text("Ketuk item untuk mengoreksi.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "#6B7280"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Scanned Bill Card
                    VStack(spacing: 0) {
                        // Items List
                        VStack(spacing: 12) {
                            ForEach(items.indices, id: \.self) { idx in
                                Button(action: {
                                    editingItemIndex = idx
                                    editingItemName = items[idx].name
                                    editingItemPrice = "\(Int(items[idx].price))"
                                    editingItemQty = items[idx].quantity
                                    showEditItemSheet = true
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .top) {
                                            Text(items[idx].name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#111827"))
                                            Spacer()
                                            Text(formatRp(items[idx].totalPrice))
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#111827"))
                                        }

                                        Text("\(items[idx].quantity) × \(formatRp(items[idx].price))")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color(hex: "#6B7280"))
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if idx < items.count - 1 {
                                    Divider()
                                        .opacity(0.3)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)

                        // Summary Rows: Subtotal, Pajak, Layanan, Total
                        VStack(spacing: 12) {
                            HStack {
                                Text("Subtotal")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color(hex: "#374151"))
                                Spacer()
                                Text(formatRp(subtotalAmount))
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color(hex: "#111827"))
                            }

                            HStack {
                                Text("Pajak")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color(hex: "#374151"))
                                Spacer()
                                Text(formatRp(taxAmount))
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color(hex: "#111827"))
                            }

                            if serviceAmount > 0 {
                                HStack {
                                    Text("Layanan")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color(hex: "#374151"))
                                    Spacer()
                                    Text(formatRp(serviceAmount))
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color(hex: "#111827"))
                                }
                            }

                            Divider()
                                .padding(.vertical, 6)

                            HStack {
                                Text("Total")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color(hex: "#111827"))
                                Spacer()
                                Text(formatRp(grandTotalAmount))
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

            // Bottom Actions: Save as Personal or Split Bill
            VStack(spacing: 10) {
                // Split Bill Button
                Button(action: proceedToParticipants) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Bagi Tagihan (Split Bill)")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "#2D50FF"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(items.isEmpty)

                // Personal Expense Button
                Button(action: saveAsPersonalExpense) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Simpan Pengeluaran Pribadi")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "#1F2937"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "#D1D5DB"), lineWidth: 1.2)
                    )
                }
                .disabled(items.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(Color(hex: "#F6F7FB"))
        }
        .background(Color(hex: "#F6F7FB"))
    }

    // Koreksi Item Bottom Sheet
    private var editItemCorrectionSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Detail Menu")) {
                    TextField("Nama Menu", text: $editingItemName)

                    HStack {
                        Text("Jumlah Porsi")
                        Spacer()
                        Stepper("\(editingItemQty)", value: $editingItemQty, in: 1...99)
                    }

                    HStack {
                        Text("Harga Satuan")
                        Spacer()
                        TextField("Rp", text: $editingItemPrice)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Button(role: .destructive, action: {
                        if let idx = editingItemIndex, items.indices.contains(idx) {
                            items.remove(at: idx)
                        }
                        showEditItemSheet = false
                    }) {
                        HStack {
                            Spacer()
                            Text("Hapus Menu Ini")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Koreksi Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        showEditItemSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        if let idx = editingItemIndex, items.indices.contains(idx) {
                            let cleanNum = Double(CurrencyFormatter.cleanNumberString(editingItemPrice)) ?? items[idx].price
                            items[idx].name = editingItemName.trimmingCharacters(in: .whitespacesAndNewlines)
                            items[idx].quantity = max(1, editingItemQty)
                            items[idx].price = cleanNum
                        }
                        showEditItemSheet = false
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func proceedToParticipants() {
        let splitItems = items.map {
            SplitItem(name: $0.name, price: $0.price, quantity: $0.quantity, assignedParticipantIds: [])
        }
        let billTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Makan Bersama"
            : title.trimmingCharacters(in: .whitespacesAndNewlines)

        let taxPct = (subtotalAmount > 0) ? (taxAmount / subtotalAmount * 100.0) : 10.0
        let servicePct = (subtotalAmount > 0) ? (serviceAmount / subtotalAmount * 100.0) : 5.0

        let session = SplitBillSession(
            title: billTitle,
            date: date,
            participants: [
                SplitParticipant(name: "Saya", phoneNumber: "")
            ],
            items: splitItems,
            taxPercentage: taxPct,
            servicePercentage: servicePct
        )
        self.preparedSession = session
        self.currentStep = .splitBill
    }

    private func saveAsPersonalExpense() {
        let billTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Makan di Restoran"
            : title.trimmingCharacters(in: .whitespacesAndNewlines)

        let expense = Expense(
            title: billTitle,
            amount: grandTotalAmount,
            category: category,
            date: date,
            note: note.isEmpty ? "Item: \(items.map { "\($0.quantity)x \($0.name)" }.joined(separator: ", "))" : note,
            inputMethod: .receiptScanner
        )
        expenseStore.addExpense(expense)
        dismiss()
    }

    // MARK: - 3. MANUAL ENTRY STEP
    private var manualEntryView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Catat Tagihan Manual")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Masukkan rincian menu dan jumlah porsi secara manual.")
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Info Tagihan
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Nama Tempat / Tagihan (cth: Solaria)", text: $title)
                        .font(.headline)
                        .padding(12)
                        .background(BagiTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    DatePicker("Tanggal", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .font(.footnote)
                        .padding(12)
                        .background(BagiTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Add Item Form
                manualInputCard

                // Items list
                billItemsTableSection

                // Mode Selection
                billModeSelectionSection

                // Action
                actionButton
                    .padding(.top, 8)
            }
            .padding()
            .padding(.bottom, 40)
        }
    }

    // MARK: - 4. VOICE ENTRY STEP
    private var voiceEntryView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Catat Tagihan via Suara")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Sebutkan nama makanan dan nominal harganya.")
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                voiceInputCard

                billItemsTableSection

                billModeSelectionSection

                actionButton
                    .padding(.top, 8)
            }
            .padding()
            .padding(.bottom, 40)
        }
    }

    private func applyReceiptResult(_ result: ReceiptScanResult) {
        title = result.merchantName
        items = result.items.map {
            BillItemEntry(name: $0.name, price: $0.price, quantity: $0.quantity)
        }
    }

    // MARK: - Manual Input Card Subcomponent
    private var manualInputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tambah Menu / Item")
                .font(.headline)

            TextField("Nama Menu (cth: Nasi Goreng, Es Jeruk)", text: $manualItemName)
                .padding(12)
                .background(BagiTheme.soft)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                HStack {
                    Text("Rp")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(BagiTheme.muted)
                    TextField("Harga Satuan", text: $manualItemPrice)
                        .keyboardType(.numberPad)
                        .font(.headline)
                }
                .padding(12)
                .background(BagiTheme.soft)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Quantity Stepper
                HStack(spacing: 8) {
                    Button(action: {
                        if manualItemQty > 1 { manualItemQty -= 1 }
                    }) {
                        Image(systemName: "minus")
                            .font(.footnote)
                            .frame(width: 32, height: 32)
                            .background(BagiTheme.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Text("\(manualItemQty)")
                        .font(.headline)
                        .frame(minWidth: 28)

                    Button(action: {
                        manualItemQty += 1
                    }) {
                        Image(systemName: "plus")
                            .font(.footnote)
                            .frame(width: 32, height: 32)
                            .background(BagiTheme.primary.opacity(0.15))
                            .foregroundStyle(BagiTheme.primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(BagiTheme.soft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button(action: addManualItem) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Tambahkan ke Daftar Menu")
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(canAddManualItem ? BagiTheme.primary : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!canAddManualItem)
        }
        .padding(16)
        .background(BagiTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
    }

    private var canAddManualItem: Bool {
        !manualItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Double(manualItemPrice) ?? 0) > 0
    }

    private func addManualItem() {
        guard let price = Double(manualItemPrice), price > 0 else { return }
        let cleanName = manualItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        items.append(BillItemEntry(name: cleanName, price: price, quantity: manualItemQty))
        manualItemName = ""
        manualItemPrice = ""
        manualItemQty = 1
    }

    // MARK: - Voice Input Card Subcomponent
    private var voiceInputCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(speechService.isRecording ? "Mendengarkan suara kamu..." : "Tekan mikrofon untuk merekam")
                    .font(.subheadline)
                    .foregroundStyle(BagiTheme.muted)

                if !speechService.transcribedText.isEmpty {
                    Text("\"\(speechService.transcribedText)\"")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            }

            Button(action: toggleVoiceRecording) {
                ZStack {
                    Circle()
                        .fill(speechService.isRecording ? Color.red.opacity(0.2) : BagiTheme.primary.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(speechService.isRecording ? Color.red : BagiTheme.primary)
                        .frame(width: 64, height: 64)

                    Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }

            if speechService.detectedAmount > 0 {
                VStack(spacing: 4) {
                    Text("Menu: \(speechService.detectedTitle.isEmpty ? "Makanan" : speechService.detectedTitle)")
                        .font(.headline)
                    Text("Total: \(CurrencyFormatter.format(speechService.detectedAmount))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(BagiTheme.primary)

                    Button(action: {
                        let name = speechService.detectedTitle.isEmpty ? "Menu Suara" : speechService.detectedTitle
                        items.append(BillItemEntry(name: name, price: speechService.detectedAmount, quantity: 1))
                        speechService.cancelRecording()
                    }) {
                        Text("+ Masukkan ke Daftar Tagihan")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(BagiTheme.primary.opacity(0.12))
                            .foregroundStyle(BagiTheme.primary)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 6)
                }
                .padding()
                .background(BagiTheme.soft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(BagiTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
    }

    private func toggleVoiceRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task {
                await speechService.requestAndStartRecording()
            }
        }
    }

    // MARK: - Items Table with Qty Stepper
    private var billItemsTableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daftar Menu Makanan (\(items.count))")
                    .font(.headline)
                Spacer()
                Text("\(totalItemsQuantity) Total Porsi")
                    .font(.footnote)
                    .foregroundStyle(BagiTheme.muted)
            }

            if items.isEmpty {
                Text("Belum ada menu yang dicatat.")
                    .font(.footnote)
                    .foregroundStyle(BagiTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("@ \(CurrencyFormatter.format(item.price))")
                                    .font(.caption)
                                    .foregroundStyle(BagiTheme.muted)
                            }

                            Spacer()

                            // Qty Stepper
                            HStack(spacing: 6) {
                                Button(action: {
                                    if items[index].quantity > 1 {
                                        items[index].quantity -= 1
                                    } else {
                                        items.remove(at: index)
                                    }
                                }) {
                                    Image(systemName: items[index].quantity == 1 ? "trash" : "minus")
                                        .font(.caption2)
                                        .frame(width: 26, height: 26)
                                        .background(BagiTheme.soft)
                                        .foregroundStyle(items[index].quantity == 1 ? .red : .primary)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Text("\(items[index].quantity)")
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .frame(minWidth: 20)

                                Button(action: {
                                    items[index].quantity += 1
                                }) {
                                    Image(systemName: "plus")
                                        .font(.caption2)
                                        .frame(width: 26, height: 26)
                                        .background(BagiTheme.primary.opacity(0.15))
                                        .foregroundStyle(BagiTheme.primary)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }

                            Text(CurrencyFormatter.format(item.totalPrice))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(minWidth: 70, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(BagiTheme.soft)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Subtotal / Total Preview
                HStack {
                    Text("Total Tagihan")
                        .font(.headline)
                    Spacer()
                    Text(CurrencyFormatter.format(totalBillAmount))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(BagiTheme.primary)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(BagiTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
    }

    // MARK: - Mode Selection: Personal vs Split Bill
    private var billModeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tujuan Tagihan Ini")
                .font(.headline)

            VStack(spacing: 10) {
                // Split Bill Option
                Button(action: { billMode = .splitBill }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.title3)
                            .foregroundStyle(billMode == .splitBill ? Color.green : BagiTheme.muted)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bagi Tagihan (Split Bill)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text("Hitung bagian masing-masing teman per makanan.")
                                .font(.caption2)
                                .foregroundStyle(BagiTheme.muted)
                        }

                        Spacer()

                        Image(systemName: billMode == .splitBill ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(billMode == .splitBill ? Color.green : BagiTheme.muted)
                    }
                    .padding(12)
                    .background(billMode == .splitBill ? Color.green.opacity(0.08) : BagiTheme.soft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(billMode == .splitBill ? Color.green : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)

                // Personal Expense Option
                Button(action: { billMode = .personal }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.title3)
                            .foregroundStyle(billMode == .personal ? BagiTheme.primary : BagiTheme.muted)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pengeluaran Pribadi")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text("Catat langsung ke total pengeluaran pribadi kamu.")
                                .font(.caption2)
                                .foregroundStyle(BagiTheme.muted)
                        }

                        Spacer()

                        Image(systemName: billMode == .personal ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(billMode == .personal ? BagiTheme.primary : BagiTheme.muted)
                    }
                    .padding(12)
                    .background(billMode == .personal ? BagiTheme.primary.opacity(0.08) : BagiTheme.soft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(billMode == .personal ? BagiTheme.primary : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }

            if billMode == .personal {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kategori Pengeluaran")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(BagiTheme.muted)

                    Picker("Kategori", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(10)
                    .background(BagiTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    TextField("Catatan tambahan (opsional)", text: $note)
                        .font(.footnote)
                        .padding(12)
                        .background(BagiTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Final Action Button
    private var actionButton: some View {
        Button(action: handleAction) {
            HStack(spacing: 8) {
                if billMode == .personal {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Simpan ke Riwayat Pengeluaran")
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Lanjut ke Pembagian Menu (\(items.count) Menu)")
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(canProceed ? (billMode == .personal ? Color(hex: "#2D50FF") : Color.green) : Color.gray.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canProceed)
    }

    private var canProceed: Bool {
        return !items.isEmpty && totalBillAmount > 0
    }

    private func handleAction() {
        let billTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (billMode == .personal ? "Pengeluaran Baru" : "Makan Bersama")
            : title.trimmingCharacters(in: .whitespacesAndNewlines)

        if billMode == .personal {
            let expense = Expense(
                title: billTitle,
                amount: totalBillAmount,
                category: category,
                date: date,
                note: note.isEmpty ? "Item: \(items.map { "\($0.quantity)x \($0.name)" }.joined(separator: ", "))" : note,
                inputMethod: .receiptScanner
            )
            expenseStore.addExpense(expense)
            dismiss()
        } else {
            let splitItems = items.map {
                SplitItem(name: $0.name, price: $0.price, quantity: $0.quantity, assignedParticipantIds: [])
            }
            let session = SplitBillSession(
                title: billTitle,
                date: date,
                participants: [
                    SplitParticipant(name: "Saya", phoneNumber: "")
                ],
                items: splitItems
            )
            self.preparedSession = session
            self.navigateToSplitBill = true
        }
    }
}

// MARK: - Viewfinder Reticle Corner Brackets Shape
struct CornerBracketsView: Shape {
    var cornerLength: CGFloat = 26

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Top Left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        // Top Right
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        // Bottom Left
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))

        // Bottom Right
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))

        return path
    }
}

// MARK: - Hex Color Helper
extension Color {
    init(hex: String) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexClean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
