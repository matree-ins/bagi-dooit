//
//  AddExpenseSheet.swift
//  JustDooit
//

import SwiftUI
import PhotosUI

struct AddExpenseSheet: View {
    @ObservedObject var expenseStore: ExpenseStore
    @Environment(\.dismiss) var dismiss

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
                        speechService.cancelRecording()
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showCameraPicker) {
                CameraPickerView(sourceType: .camera) { image in
                    scannerService.processImage(image)
                }
            }
            .task(id: selectedPhotoItem) {
                guard let selectedPhotoItem else { return }
                do {
                    guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
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
                guard selectedTab == .receiptScanner else { return }
                applyReceiptResult(result)
            }
            .onChange(of: speechService.transcribedText) { _, _ in
                guard selectedTab == .voice else { return }
                applySpeechResult()
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if oldValue == .voice { speechService.cancelRecording() }
                if newValue == .voice { applySpeechResult() }
                if newValue == .receiptScanner { applyReceiptResult(scannerService.scanResult) }
            }
            .onDisappear { speechService.cancelRecording() }
        }
    }

    private var isSaveValid: Bool {
        let amt = Double(amountText) ?? 0
        let inputBusy = (selectedTab == .voice && (speechService.isRecording || speechService.isRequestingPermission))
            || (selectedTab == .receiptScanner && scannerService.isScanning)
        let inputReady: Bool
        switch selectedTab {
        case .manual:
            inputReady = true
        case .voice:
            inputReady = !speechService.transcribedText.isEmpty && speechService.errorMessage == nil
        case .receiptScanner:
            inputReady = scannerService.scanResult != nil && scannerService.errorMessage == nil
        }
        return inputReady && !inputBusy && amt.isFinite && !title.trimmingCharacters(in: .whitespaces).isEmpty && amt > 0
    }

    private func applyReceiptResult(_ result: ReceiptScanResult?) {
        title = result?.merchantName ?? ""
        amountText = result.map { String(Int($0.totalAmount)) } ?? ""
    }

    private func applySpeechResult() {
        title = speechService.transcribedText.isEmpty ? "" : speechService.detectedTitle
        amountText = !speechService.transcribedText.isEmpty && speechService.detectedAmount > 0
            ? String(Int(speechService.detectedAmount)) : ""
        category = speechService.detectedCategory
    }

    private func saveExpense() {
        guard isSaveValid, let amt = Double(amountText), amt > 0 else { return }
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
        dismiss()
    }

    // MARK: - Manual Section
    private var manualInputSection: some View {
        ManualExpenseInputView(title: $title, amountText: $amountText, category: $category, date: $date, note: $note)
    }

    // MARK: - Voice Input Section
    private var voiceInputSection: some View {
        VoiceExpenseInputView(speechService: speechService)
    }

    // MARK: - Receipt Scanner Section
    private var receiptScannerSection: some View {
        ReceiptExpenseInputView(scannerService: scannerService, showCameraPicker: $showCameraPicker, selectedPhotoItem: $selectedPhotoItem)
    }
}
