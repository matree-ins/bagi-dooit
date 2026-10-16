//
//  AddExpenseSheet.swift
//  JustDooit
//

import SwiftUI
import PhotosUI

struct AddExpenseSheet: View {
    @ObservedObject var expenseStore: ExpenseStore
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedTab: ExpenseInputMethod = .manual

    // Manual Form State
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var category: ExpenseCategory = .food
    @State private var date: Date = Date()
    @State private var note: String = ""

    // Voice Service State
    @StateObject private var speechService = SpeechRecognitionService()

    // Scanner Service State
    @StateObject private var scannerService = ReceiptScannerService()
    @State private var showCameraPicker: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input Mode Segmented Control
                Picker("Metode Input", selection: $selectedTab) {
                    Label("Manual", systemImage: ExpenseInputMethod.manual.icon).tag(ExpenseInputMethod.manual)
                    Label("Suara", systemImage: ExpenseInputMethod.voice.icon).tag(ExpenseInputMethod.voice)
                    Label("Scan Bon", systemImage: ExpenseInputMethod.receiptScanner.icon).tag(ExpenseInputMethod.receiptScanner)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content View according to selected tab
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .manual:
                            manualInputSection
                        case .voice:
                            voiceInputSection
                        case .receiptScanner:
                            receiptScannerSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }

                // Bottom Save Button
                Button(action: saveExpense) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Simpan Pengeluaran")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSaveValid ? Color.blue : Color.gray.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isSaveValid)
                .padding()
            }
            .navigationTitle("Catat Pengeluaran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        speechService.stopRecording()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showCameraPicker) {
                CameraPickerView(sourceType: .camera) { image in
                    scannerService.processImage(image)
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        scannerService.processImage(image)
                    }
                }
            }
            .onChange(of: scannerService.scanResult?.totalAmount) { newTotal in
                if let newTotal = newTotal, newTotal > 0 {
                    self.amountText = "\(Int(newTotal))"
                    if let merchant = scannerService.scanResult?.merchantName {
                        self.title = merchant
                    }
                }
            }
        }
    }

    private var isSaveValid: Bool {
        let amt = Double(amountText) ?? 0
        return !title.trimmingCharacters(in: .whitespaces).isEmpty && amt > 0
    }

    private func saveExpense() {
        guard let amt = Double(amountText), amt > 0 else { return }
        let newExpense = Expense(
            title: title.trimmingCharacters(in: .whitespaces),
            amount: amt,
            category: category,
            date: date,
            note: note,
            inputMethod: selectedTab
        )
        expenseStore.addExpense(newExpense)
        speechService.stopRecording()
        presentationMode.wrappedValue.dismiss()
    }

    // MARK: - Manual Section
    private var manualInputSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nama Pengeluaran")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Contoh: Nasi Goreng, Bensin, Kopi", text: $title)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Nominal (Rp)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Rp")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $amountText)
                        .keyboardType(.numberPad)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Quick Add amount chips
                HStack(spacing: 8) {
                    quickAmountButton(label: "+10rb", amount: 10_000)
                    quickAmountButton(label: "+25rb", amount: 25_000)
                    quickAmountButton(label: "+50rb", amount: 50_000)
                    quickAmountButton(label: "+100rb", amount: 100_000)
                }
                .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Kategori")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Button(action: { self.category = cat }) {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                    Text(cat.rawValue)
                                }
                                .font(.footnote)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(category == cat ? cat.color.opacity(0.2) : Color(UIColor.secondarySystemBackground))
                                .foregroundStyle(category == cat ? cat.color : .primary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(category == cat ? cat.color : Color.clear, lineWidth: 1.5)
                                )
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            DatePicker("Tanggal", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text("Catatan (Opsional)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Tambah catatan...", text: $note)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func quickAmountButton(label: String, amount: Double) -> some View {
        Button(action: {
            let current = Double(amountText) ?? 0
            amountText = "\(Int(current + amount))"
        }) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.12))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        }
    }

    // MARK: - Voice Input Section
    private var voiceInputSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Bicara untuk Catat Pengeluaran")
                    .font(.headline)
                Text("Contoh: \"Makan siang soto tiga puluh lima ribu\" atau \"Isi bensin lima puluh ribu\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Mic Record Button
            ZStack {
                Circle()
                    .fill(speechService.isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.1))
                    .frame(width: 110, height: 110)
                    .scaleEffect(speechService.isRecording ? 1.15 : 1.0)
                    .animation(speechService.isRecording ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: speechService.isRecording)

                Button(action: {
                    if speechService.isRecording {
                        speechService.stopRecording()
                        applySpeechResult()
                    } else {
                        speechService.requestAuthorization { granted in
                            if granted {
                                speechService.startRecording()
                            }
                        }
                    }
                }) {
                    Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(speechService.isRecording ? Color.red : Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
            }

            Text(speechService.isRecording ? "Mendengarkan... Tekan tombol untuk selesai" : "Tekan mikrofon untuk mulai berbicara")
                .font(.footnote)
                .foregroundStyle(speechService.isRecording ? .red : .secondary)

            // Transcribed Result Card
            if !speechService.transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hasil Suara Terdeteksi:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)

                    Text("\"\(speechService.transcribedText)\"")
                        .font(.body)
                        .italic()

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Judul")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(speechService.detectedTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Nominal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(CurrencyFormatter.format(speechService.detectedAmount))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                    }

                    HStack {
                        Text("Kategori Otomatis:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Label(speechService.detectedCategory.rawValue, systemImage: speechService.detectedCategory.icon)
                            .font(.caption)
                            .foregroundStyle(speechService.detectedCategory.color)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Demo Voice Simulator Presets (Ideal for Hackathon Judges)
            VStack(alignment: .leading, spacing: 10) {
                Text("Simulasi Suara Cepat (Hackathon Demo):")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    demoVoiceButton(text: "Beli Kopi Kenangan 28 ribu")
                    demoVoiceButton(text: "Isi Bensin Pertamax 50 ribu")
                    demoVoiceButton(text: "Makan Nasi Padang 35 ribu")
                    demoVoiceButton(text: "Bayar Tagihan Wifi 250 ribu")
                }
            }
            .padding(.top, 8)
        }
    }

    private func applySpeechResult() {
        if !speechService.detectedTitle.isEmpty {
            self.title = speechService.detectedTitle
        }
        if speechService.detectedAmount > 0 {
            self.amountText = "\(Int(speechService.detectedAmount))"
        }
        self.category = speechService.detectedCategory
    }

    private func demoVoiceButton(text: String) -> some View {
        Button(action: {
            speechService.simulateVoiceInput(text)
            applySpeechResult()
        }) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.blue)
                Text("\"\(text)\"")
                    .font(.caption)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Receipt Scanner Section
    private var receiptScannerSection: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Scan Struk / Bon Belanja (OCR)")
                    .font(.headline)
                Text("Gunakan kamera untuk membaca total belanja dan rincian item secara otomatis.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Scan Action Buttons
            HStack(spacing: 12) {
                Button(action: { showCameraPicker = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Kamera")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                        Text("Galeri Foto")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green.opacity(0.12))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: { scannerService.loadDemoReceipt() }) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.title2)
                        Text("Demo Struk")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange.opacity(0.12))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if scannerService.isScanning {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Memproses OCR dengan Vision...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            // Scanned Result Preview
            if let result = scannerService.scanResult {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Merchant / Toko")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(result.merchantName)
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Total Terdeteksi")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(CurrencyFormatter.format(result.totalAmount))
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                    }

                    Divider()

                    if !result.items.isEmpty {
                        Text("Item Terdeteksi (\(result.items.count)):")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)

                        ForEach(result.items) { item in
                            HStack {
                                Text(item.name)
                                    .font(.caption)
                                Spacer()
                                Text(CurrencyFormatter.format(item.price))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}
