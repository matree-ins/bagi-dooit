//
//  SpeechRecognitionService.swift
//  JustDooit
//

import SwiftUI
import Combine
import Speech
import AVFoundation

class SpeechRecognitionService: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var transcribedText: String = ""
    @Published var detectedTitle: String = ""
    @Published var detectedAmount: Double = 0
    @Published var detectedCategory: ExpenseCategory = .food
    @Published var errorMessage: String?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        super.init()
        // Try Indonesian locale first, fallback to current or US
        if let idRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "id-ID")), idRecognizer.isAvailable {
            self.speechRecognizer = idRecognizer
        } else {
            self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    AVAudioApplication.requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            completion(granted)
                        }
                    }
                default:
                    completion(false)
                }
            }
        }
    }

    func startRecording() {
        guard !isRecording else { return }

        // Cancel previous task if any
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.errorMessage = "Gagal mengaktifkan audio session: \(error.localizedDescription)"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            self.errorMessage = "Tidak dapat membuat speech request."
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            errorMessage = "Mikrofon belum tersedia. Coba lagi."
            self.recognitionRequest = nil
            try? audioSession.setActive(false)
            return
        }

        do {
            // iOS 27 supplies immutable buffers; Speech still takes a mutable PCM buffer.
            // The new tap API supports buffers of at least 100 milliseconds.
            let bufferSize = AVAudioFrameCount(recordingFormat.sampleRate * 0.1)
            try inputNode.installAudioTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(AVAudioPCMBuffer(copying: buffer))
            }
        } catch {
            errorMessage = "Gagal menyiapkan mikrofon: \(error.localizedDescription)"
            self.recognitionRequest = nil
            try? audioSession.setActive(false)
            return
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            transcribedText = ""
            errorMessage = nil
        } catch {
            audioEngine.inputNode.removeTap(onBus: 0)
            self.recognitionRequest = nil
            try? audioSession.setActive(false)
            self.errorMessage = "Gagal memulai audio engine: \(error.localizedDescription)"
            return
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
            guard let self = self else { return }

            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
                self.parseSpokenText(self.transcribedText)
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopRecording()
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()

        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // Direct parser for testing or simulation
    func simulateVoiceInput(_ text: String) {
        self.transcribedText = text
        parseSpokenText(text)
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
