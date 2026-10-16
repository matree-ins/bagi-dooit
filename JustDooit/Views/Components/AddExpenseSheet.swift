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
                    Label("Scan struk", systemImage: ExpenseInputMethod.receiptScanner.icon).tag(ExpenseInputMethod.receiptScanner)
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
                    .background(isSaveValid ? BagiTheme.primary : Color.gray.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
                }
                .disabled(!isSaveValid)
                .padding()
            }
            .bagiScreen()
            .navigationTitle("Catat pengeluaran")
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
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        scannerService.processImage(image)
                    }
                }
            }
            .onChange(of: scannerService.scanResult?.totalAmount) { _, newTotal in
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
        ManualExpenseInputView(title: $title, amountText: $amountText, category: $category, date: $date, note: $note)
    }

    // MARK: - Voice Input Section
    private var voiceInputSection: some View {
        VoiceExpenseInputView(speechService: speechService, title: $title, amountText: $amountText, category: $category)
    }

    // MARK: - Receipt Scanner Section
    private var receiptScannerSection: some View {
        ReceiptExpenseInputView(scannerService: scannerService, showCameraPicker: $showCameraPicker, selectedPhotoItem: $selectedPhotoItem)
    }
}
