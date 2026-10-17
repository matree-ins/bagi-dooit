import SwiftUI
import Combine
import Speech
import AVFoundation

@MainActor
final class SpeechRecognitionService: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isRequestingPermission = false
    @Published private(set) var transcribedText = ""
    @Published private(set) var detectedTitle = ""
    @Published private(set) var detectedAmount: Double = 0
    @Published private(set) var detectedCategory: ExpenseCategory = .food
    @Published var errorMessage: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "id-ID"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var tapInstalled = false
    private var attempt = UUID()

    func requestAndStartRecording() async {
        guard !isRecording, !isRequestingPermission else { return }
        cancelRecording()
        let currentAttempt = attempt
        isRequestingPermission = true
        errorMessage = nil
        defer {
            if attempt == currentAttempt { isRequestingPermission = false }
        }

        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard attempt == currentAttempt, !Task.isCancelled else { return }
        guard authorization == .authorized else {
            errorMessage = "Izinkan pengenalan suara di Pengaturan untuk menggunakan mikrofon."
            return
        }
        let microphoneAllowed = await AVAudioApplication.requestRecordPermission()
        guard attempt == currentAttempt, !Task.isCancelled else { return }
        guard microphoneAllowed else {
            errorMessage = "Akses mikrofon ditolak. Izinkan akses di Pengaturan atau gunakan input manual."
            return
        }
        beginRecording(attempt: currentAttempt)
    }

    private func beginRecording(attempt currentAttempt: UUID) {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Pengenalan suara bahasa Indonesia belum tersedia. Coba lagi atau gunakan input manual."
            return
        }
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                errorMessage = "Mikrofon belum tersedia. Coba lagi."
                releaseAudio()
                return
            }
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request
            let bufferSize = AVAudioFrameCount(format.sampleRate * 0.1)
            try input.installAudioTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
                request.append(AVAudioPCMBuffer(copying: buffer))
            }
            tapInstalled = true
            audioEngine.prepare()
            try audioEngine.start()
            transcribedText = ""
            detectedTitle = ""
            detectedAmount = 0
            isRecording = true

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                let transcript = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let failure = error?.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, self.attempt == currentAttempt else { return }
                    if let transcript {
                        self.parseSpokenText(transcript)
                        self.transcribedText = transcript
                    }
                    if isFinal || failure != nil {
                        self.releaseAudio()
                        self.recognitionTask = nil
                        if let failure, !isFinal {
                            self.errorMessage = "Pengenalan suara berhenti: \(failure)"
                        }
                    }
                }
            }
        } catch {
            releaseAudio()
            errorMessage = "Gagal memulai mikrofon: \(error.localizedDescription)"
        }
    }

    /// Stop capturing, but accept the final recognition result for this attempt.
    func stopRecording() {
        releaseAudio()
        recognitionTask?.finish()
    }

    /// Invalidate pending permissions and callbacks when the input view disappears.
    func cancelRecording() {
        attempt = UUID()
        isRequestingPermission = false
        releaseAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func releaseAudio() {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func simulateVoiceInput(_ text: String) {
        cancelRecording()
        errorMessage = nil
        parseSpokenText(text)
        transcribedText = text
    }

    func parseSpokenText(_ text: String) {
        let lower = text.lowercased()

        // 1. Detect Amount
        var amount: Double = 0

        // Regex for patterns like "50 ribu", "50rb", "50k", "50.000", "50000"
        let ribuPattern = #"(\d+[\d.,]*)\s*(ribu|rb|k)\b"#
        let jutaPattern = #"(\d+[\d.,]*)\s*(juta|jt)\b"#
        let plainPattern = #"\b(\d{4,9})\b"#

        if let match = lower.range(of: ribuPattern, options: .regularExpression) {
            let matchedStr = String(lower[match])
            let numStr = matchedStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            if let val = Double(numStr) {
                amount = val * 1000
            }
        } else if let match = lower.range(of: jutaPattern, options: .regularExpression) {
            let matchedStr = String(lower[match])
            let numStr = matchedStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            if let val = Double(numStr) {
                amount = val * 1_000_000
            }
        } else if let match = lower.range(of: plainPattern, options: .regularExpression) {
            let matchedStr = String(lower[match])
            if let val = Double(matchedStr) {
                amount = val
            }
        }

        // Indonesian word numbers fallback (e.g. "sepuluh ribu", "lima puluh ribu")
        if amount == 0 {
            if lower.contains("seratus ribu") { amount = 100_000 }
            else if lower.contains("lima puluh ribu") { amount = 50_000 }
            else if lower.contains("dua puluh lima ribu") { amount = 25_000 }
            else if lower.contains("tiga puluh ribu") { amount = 30_000 }
            else if lower.contains("dua puluh ribu") { amount = 20_000 }
            else if lower.contains("sepuluh ribu") { amount = 10_000 }
            else if lower.contains("lima belas ribu") { amount = 15_000 }
            else if lower.contains("satu juta") { amount = 1_000_000 }
        }

        self.detectedAmount = amount

        // 2. Detect Category
        if lower.contains("makan") || lower.contains("kopi") || lower.contains("minum") || lower.contains("bakso") || lower.contains("nasi") || lower.contains("cafe") || lower.contains("sate") || lower.contains("ayam") || lower.contains("resto") {
            self.detectedCategory = .food
        } else if lower.contains("bensin") || lower.contains("gojek") || lower.contains("grab") || lower.contains("parkir") || lower.contains("tol") || lower.contains("ojol") || lower.contains("kereta") || lower.contains("mrt") {
            self.detectedCategory = .transport
        } else if lower.contains("beli") || lower.contains("belanja") || lower.contains("baju") || lower.contains("sepatu") || lower.contains("indomaret") || lower.contains("alfamart") {
            self.detectedCategory = .shopping
        } else if lower.contains("listrik") || lower.contains("pln") || lower.contains("air") || lower.contains("wifi") || lower.contains("pulsa") || lower.contains("kuota") {
            self.detectedCategory = .bills
        } else if lower.contains("nonton") || lower.contains("bioskop") || lower.contains("game") || lower.contains("netflix") || lower.contains("spotify") {
            self.detectedCategory = .entertainment
        } else if lower.contains("obat") || lower.contains("dokter") || lower.contains("apotek") || lower.contains("vitamin") {
            self.detectedCategory = .health
        } else {
            self.detectedCategory = .other
        }

        // 3. Detect Title (capitalize first letter)
        let cleanTitle = text
        if !cleanTitle.isEmpty {
            self.detectedTitle = cleanTitle.prefix(1).uppercased() + cleanTitle.dropFirst()
        } else {
            self.detectedTitle = "Pengeluaran Suara"
        }
    }
}
