import SwiftUI
import PhotosUI

struct AddExpenseSheet: View {
    var expenseStore: ExpenseStore
    @Environment(\.dismiss) private var dismiss

    init(expenseStore: ExpenseStore, quickEntry: QuickEntryRequest? = nil) {
        self.expenseStore = expenseStore
        let step: EntryStep
        switch quickEntry?.method {
        case .manual: step = .manualEntry
        case .voice: step = .voiceEntry
        default: step = .scanReceipt
        }
        _currentStep = State(initialValue: step)
        if let request = quickEntry {
            _billMode = State(initialValue: request.method == .voice ? .splitBill : .personal)
            _title = State(initialValue: request.title)
            if let amount = request.amount {
                _items = State(initialValue: [BillItemEntry(name: request.title, price: amount, quantity: 1)])
            }
        }
    }

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
    @State private var personalAmountText: String = ""
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
    @State private var splitEntryStep: EntryStep = .reviewBill
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
                BagiTheme.background
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
                            onBack: {
                                withAnimation {
                                    currentStep = splitEntryStep
                                    preparedSession = nil
                                }
                            }
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
                                .foregroundStyle(BagiTheme.primary)
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
        personalAmountText = ""
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
                    .foregroundStyle(BagiTheme.muted)
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
                        .foregroundStyle(BagiTheme.ink)
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
                    .foregroundStyle(BagiTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(BagiTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(BagiTheme.border, lineWidth: 1)
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
                    .foregroundStyle(BagiTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(BagiTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(BagiTheme.border, lineWidth: 1)
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
                    .foregroundStyle(BagiTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(BagiTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(BagiTheme.border, lineWidth: 1)
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
                .frame(minHeight: 52)
                .background(BagiTheme.action)
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
                    .foregroundStyle(BagiTheme.paperInk.opacity(0.85))

                Text("16 Okt 2026 • Meja 04")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(BagiTheme.paperInk.opacity(0.6))

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
                        .foregroundStyle(BagiTheme.paperInk)
                    Spacer()
                    Text("Rp138.000")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(BagiTheme.paperInk)
                }
            }
            .padding(14)
            .frame(width: 215)
            .background(BagiTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: BagiTheme.paperInk.opacity(0.2), radius: 8, x: 0, y: 4)

            // Green Pill: "✓ Seluruh struk terlihat"
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(BagiTheme.success)
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
                .foregroundStyle(BagiTheme.paperInk.opacity(0.8))
            Spacer()
            Text(price)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BagiTheme.paperInk.opacity(0.8))
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
                            .foregroundStyle(BagiTheme.ink)

                        Text("Ketuk item untuk mengoreksi.")
                            .font(.system(size: 15))
                            .foregroundStyle(BagiTheme.muted)
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
                                                .foregroundStyle(BagiTheme.ink)
                                            Spacer()
                                            Text(formatRp(items[idx].totalPrice))
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(BagiTheme.ink)
                                        }

                                        Text("\(items[idx].quantity) × \(formatRp(items[idx].price))")
                                            .font(.system(size: 14))
                                            .foregroundStyle(BagiTheme.muted)
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
                                    .foregroundStyle(BagiTheme.ink)
                                Spacer()
                                Text(formatRp(subtotalAmount))
                                    .font(.system(size: 15))
                                    .foregroundStyle(BagiTheme.ink)
                            }

                            HStack {
                                Text("Pajak")
                                    .font(.system(size: 15))
                                    .foregroundStyle(BagiTheme.ink)
                                Spacer()
                                Text(formatRp(taxAmount))
                                    .font(.system(size: 15))
                                    .foregroundStyle(BagiTheme.ink)
                            }

                            if serviceAmount > 0 {
                                HStack {
                                    Text("Layanan")
                                        .font(.system(size: 15))
                                        .foregroundStyle(BagiTheme.ink)
                                    Spacer()
                                    Text(formatRp(serviceAmount))
                                        .font(.system(size: 15))
                                        .foregroundStyle(BagiTheme.ink)
                                }
                            }

                            Divider()
                                .padding(.vertical, 6)

                            HStack {
                                Text("Total")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(BagiTheme.ink)
                                Spacer()
                                Text(formatRp(grandTotalAmount))
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(BagiTheme.ink)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(BagiTheme.surface)
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
                    .background(BagiTheme.action)
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
                    .foregroundStyle(BagiTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(BagiTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(BagiTheme.border, lineWidth: 1.2)
                    )
                }
                .disabled(items.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(BagiTheme.background)
        }
        .background(BagiTheme.background)
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
        splitEntryStep = .reviewBill
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

    // MARK: - 3. MANUAL ENTRY STEP (Beranda Design System)
    private var manualEntryView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Catat Tagihan Manual")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(hex: "#111827"))

                    Text("Bagi tagihan bersama teman atau simpan ke pengeluaran pribadi.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

                // Mode Selector Pills
                billModePills

                if billMode == .splitBill {
                    splitBillInfoCard
                    manualInputCard
                    billItemsTableSection
                } else {
                    personalExpenseInfoCard
                    personalAmountCard
                    personalCategoryCard
                    personalNoteCard
                }

                // Final Action Button
                actionButton
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Mode Selector Pills
    private var billModePills: some View {
        HStack(spacing: 10) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    billMode = .splitBill
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Bagi Tagihan")
                        .font(.system(size: 14, weight: billMode == .splitBill ? .bold : .medium))
                }
                .foregroundStyle(billMode == .splitBill ? .white : Color(hex: "#6B7280"))
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(billMode == .splitBill ? Color(hex: "#3A6CFF") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: billMode == .splitBill ? Color(hex: "#3A6CFF").opacity(0.25) : Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    billMode = .personal
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Pengeluaran Pribadi")
                        .font(.system(size: 14, weight: billMode == .personal ? .bold : .medium))
                }
                .foregroundStyle(billMode == .personal ? .white : Color(hex: "#6B7280"))
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(billMode == .personal ? Color(hex: "#3A6CFF") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: billMode == .personal ? Color(hex: "#3A6CFF").opacity(0.25) : Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Split Bill Info Card
    private var splitBillInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Informasi Tagihan")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            VStack(alignment: .leading, spacing: 6) {
                Text("Nama Tempat / Acara")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#6B7280"))

                TextField("Contoh: Solaria, Ngopi Bareng", text: $title)
                    .font(.system(size: 15))
                    .padding(12)
                    .background(Color(hex: "#F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Waktu Tagihan")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#6B7280"))

                DatePicker("Waktu Tagihan", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(hex: "#F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Manual Input Card Subcomponent
    private var manualInputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tambah Menu / Item")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            VStack(alignment: .leading, spacing: 6) {
                Text("Nama Menu")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#6B7280"))

                TextField("Contoh: Nasi Goreng, Es Jeruk", text: $manualItemName)
                    .font(.system(size: 15))
                    .padding(12)
                    .background(Color(hex: "#F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Harga Satuan")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#6B7280"))

                    HStack {
                        Text("Rp")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "#9CA3AF"))
                        TextField("0", text: $manualItemPrice)
                            .keyboardType(.numberPad)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(12)
                    .background(Color(hex: "#F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Porsi")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#6B7280"))

                    HStack(spacing: 8) {
                        Button(action: {
                            if manualItemQty > 1 { manualItemQty -= 1 }
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Color(hex: "#F3F4F6"))
                                .foregroundStyle(Color(hex: "#4B5563"))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Text("\(manualItemQty)")
                            .font(.system(size: 15, weight: .bold))
                            .frame(minWidth: 24)

                        Button(action: {
                            manualItemQty += 1
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Color(hex: "#3A6CFF").opacity(0.12))
                                .foregroundStyle(Color(hex: "#3A6CFF"))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(hex: "#F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
                }
            }

            Button(action: addManualItem) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Tambahkan ke Daftar Menu")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(canAddManualItem ? Color(hex: "#3A6CFF") : Color.gray.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!canAddManualItem)
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var canAddManualItem: Bool {
        !manualItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Double(CurrencyFormatter.cleanNumberString(manualItemPrice)) ?? 0) > 0
    }

    private func addManualItem() {
        guard let price = Double(CurrencyFormatter.cleanNumberString(manualItemPrice)), price > 0 else { return }
        let cleanName = manualItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        items.append(BillItemEntry(name: cleanName, price: price, quantity: manualItemQty))
        manualItemName = ""
        manualItemPrice = ""
        manualItemQty = 1
    }

    // MARK: - Items Table with Qty Stepper
    private var billItemsTableSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daftar Menu Tagihan")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#111827"))
                Spacer()
                Text("\(items.count) Menu • \(totalItemsQuantity) Porsi")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "#6B7280"))
            }

            if items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 26))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                    Text("Belum ada menu yang ditambahkan")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(hex: "#111827"))
                                Text("\(formatRp(item.price)) × \(item.quantity)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: "#6B7280"))
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Button(action: {
                                    if items[index].quantity > 1 {
                                        items[index].quantity -= 1
                                    } else {
                                        items.remove(at: index)
                                    }
                                }) {
                                    Image(systemName: items[index].quantity == 1 ? "trash" : "minus")
                                        .font(.system(size: 11, weight: .bold))
                                        .frame(width: 28, height: 28)
                                        .background(items[index].quantity == 1 ? Color(hex: "#FEE2E2") : Color(hex: "#F3F4F6"))
                                        .foregroundStyle(items[index].quantity == 1 ? Color(hex: "#EF4444") : Color(hex: "#4B5563"))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Text("\(items[index].quantity)")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(minWidth: 20)

                                Button(action: {
                                    items[index].quantity += 1
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                        .frame(width: 28, height: 28)
                                        .background(Color(hex: "#3A6CFF").opacity(0.12))
                                        .foregroundStyle(Color(hex: "#3A6CFF"))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }

                            Text(formatRp(item.totalPrice))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#111827"))
                                .frame(minWidth: 70, alignment: .trailing)
                        }
                        .padding(10)
                        .background(Color(hex: "#F9FAFB"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Text("Total Tagihan")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: "#111827"))
                    Spacer()
                    Text(formatRp(totalBillAmount))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#3A6CFF"))
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Personal Expense Cards
    private var personalExpenseInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Detail Pengeluaran")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            VStack(alignment: .leading, spacing: 6) {
                Text("Nama Pengeluaran")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#6B7280"))

                TextField("Contoh: Makan Siang, Bensin, Kopi", text: $title)
                    .font(.system(size: 15))
                    .padding(12)
                    .background(Color(hex: "#F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tanggal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#6B7280"))

                DatePicker("Tanggal", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(hex: "#F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                    )
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var personalAmountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nominal Pengeluaran")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            HStack {
                Text("Rp")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color(hex: "#3A6CFF"))
                TextField("0", text: $personalAmountText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color(hex: "#111827"))
            }
            .padding(14)
            .background(Color(hex: "#F9FAFB"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#3A6CFF").opacity(0.3), lineWidth: 1.5)
            )

            // Quick Amount Buttons
            HStack(spacing: 8) {
                quickAmountPill(label: "+10rb", value: 10_000)
                quickAmountPill(label: "+25rb", value: 25_000)
                quickAmountPill(label: "+50rb", value: 50_000)
                quickAmountPill(label: "+100rb", value: 100_000)
            }

            if totalBillAmount > 0 {
                Button(action: {
                    personalAmountText = "\(Int(totalBillAmount))"
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text("Gunakan total daftar menu: \(formatRp(totalBillAmount))")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "#3A6CFF"))
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func quickAmountPill(label: String, value: Double) -> some View {
        Button(action: {
            let current = Double(CurrencyFormatter.cleanNumberString(personalAmountText)) ?? 0
            personalAmountText = "\(Int(current + value))"
        }) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#3A6CFF"))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#3A6CFF").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var personalCategoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kategori Pengeluaran")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExpenseCategory.allCases) { cat in
                        let isSelected = category == cat
                        Button(action: { category = cat }) {
                            HStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 13))
                                Text(cat.rawValue)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            }
                            .foregroundStyle(isSelected ? .white : Color(hex: "#4B5563"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? cat.color : Color(hex: "#F9FAFB"))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Color(hex: "#E5E7EB"), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var personalNoteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Catatan (Opsional)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            TextField("Tambah catatan tambahan...", text: $note)
                .font(.system(size: 15))
                .padding(12)
                .background(Color(hex: "#F9FAFB"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
                )
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - 4. VOICE ENTRY STEP
    private var voiceEntryView: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Catat Tagihan via Suara")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(hex: "#111827"))

                    Text("Sebutkan nama makanan dan nominal harganya")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

                billModePills

                voiceInputCard

                billItemsTableSection

                actionButton
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func applyReceiptResult(_ result: ReceiptScanResult) {
        title = result.merchantName
        items = result.items.map {
            BillItemEntry(name: $0.name, price: $0.price, quantity: $0.quantity)
        }
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
                        .fill(speechService.isRecording ? Color.red.opacity(0.2) : Color(hex: "#3A6CFF").opacity(0.15))
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(speechService.isRecording ? Color.red : Color(hex: "#3A6CFF"))
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
                        .foregroundStyle(Color(hex: "#3A6CFF"))

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
                            .background(Color(hex: "#3A6CFF").opacity(0.12))
                            .foregroundStyle(Color(hex: "#3A6CFF"))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 6)
                }
                .padding()
                .background(Color(hex: "#F9FAFB"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
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

    // MARK: - Final Action Button
    private var actionButton: some View {
        Button(action: handleAction) {
            HStack(spacing: 8) {
                if billMode == .personal {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Simpan Pengeluaran Pribadi")
                        .font(.system(size: 16, weight: .bold))
                } else {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(items.isEmpty ? "Lanjut ke Bagi Tagihan" : "Lanjut ke Pembagian (\(items.count) Menu)")
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(canProceed ? Color(hex: "#3A6CFF") : Color.gray.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: canProceed ? Color(hex: "#3A6CFF").opacity(0.25) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!canProceed)
    }

    private var canProceed: Bool {
        if billMode == .personal {
            let direct = Double(CurrencyFormatter.cleanNumberString(personalAmountText)) ?? 0
            return direct > 0 || (totalBillAmount.isFinite && totalBillAmount > 0)
        } else {
            let scratch = Double(CurrencyFormatter.cleanNumberString(manualItemPrice)) ?? 0
            return !items.isEmpty || scratch > 0
        }
    }

    private func handleAction() {
        guard canProceed else { return }
        speechService.cancelRecording()
        let billTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (billMode == .personal ? "Pengeluaran Baru" : "Makan Bersama")
            : title.trimmingCharacters(in: .whitespacesAndNewlines)

        if billMode == .personal {
            let directAmount = Double(CurrencyFormatter.cleanNumberString(personalAmountText)) ?? 0
            let finalAmount = directAmount > 0 ? directAmount : totalBillAmount
            guard finalAmount > 0 else { return }

            let itemNote = items.isEmpty ? "" : "Item: \(items.map { "\($0.quantity)x \($0.name)" }.joined(separator: ", "))"
            let finalNote = note.isEmpty ? itemNote : (itemNote.isEmpty ? note : "\(note) (\(itemNote))")

            let expense = Expense(
                title: billTitle,
                amount: finalAmount,
                category: category,
                date: date,
                note: finalNote,
                inputMethod: currentStep == .voiceEntry ? .voice : .manual
            )
            expenseStore.addExpense(expense)
            dismiss()
        } else {
            var splitItems = items.map {
                SplitItem(name: $0.name, price: $0.price, quantity: $0.quantity, assignedParticipantIds: [])
            }
            let scratchPrice = Double(CurrencyFormatter.cleanNumberString(manualItemPrice)) ?? 0
            if scratchPrice > 0 {
                let name = manualItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Menu Makanan" : manualItemName.trimmingCharacters(in: .whitespacesAndNewlines)
                splitItems.append(SplitItem(name: name, price: scratchPrice, quantity: manualItemQty, assignedParticipantIds: []))
            }
            guard !splitItems.isEmpty else { return }

            let session = SplitBillSession(
                title: billTitle,
                date: date,
                participants: [
                    SplitParticipant(name: "Saya", phoneNumber: "")
                ],
                items: splitItems
            )
            splitEntryStep = currentStep
            self.preparedSession = session
            withAnimation(.easeInOut(duration: 0.25)) {
                self.currentStep = .splitBill
            }
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
