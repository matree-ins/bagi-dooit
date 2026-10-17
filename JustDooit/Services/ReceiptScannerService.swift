import SwiftUI
import Combine
import Vision
import UIKit

class ReceiptScannerService: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var scanResult: ReceiptScanResult?
    @Published var errorMessage: String?
    private var scanID = UUID()

    func processImage(_ image: UIImage) {
        scanID = UUID()
        let currentScanID = scanID
        scanResult = nil
        errorMessage = nil
        isScanning = false
        guard let cgImage = image.cgImage else {
            errorMessage = "Gagal membaca format gambar."
            return
        }

        isScanning = true
        errorMessage = nil

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] (req, err) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.scanID == currentScanID else { return }
                self.isScanning = false
                if let err = err {
                    self.errorMessage = "Gagal memindai teks: \(err.localizedDescription)"
                    return
                }

                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    self.errorMessage = "Tidak ada teks terdeteksi."
                    return
                }

                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                guard !lines.isEmpty else {
                    self.errorMessage = "Teks struk belum terbaca. Coba foto yang lebih jelas."
                    return
                }
                self.scanResult = self.parseReceiptLines(lines)
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    guard self.scanID == currentScanID else { return }
                    self.isScanning = false
                    self.errorMessage = "Terjadi kesalahan saat OCR: \(error.localizedDescription)"
                }
            }
        }
    }

    private func parseReceiptLines(_ lines: [String]) -> ReceiptScanResult {
        var merchant = lines.first ?? "Struk Belanja"
        var items: [ScannedReceiptItem] = []
        var detectedTotal: Double = 0

        let amountRegex = #"(\d{1,3}(?:[.,]\d{3})*|\d{3,7})"#

        for line in lines {
            let lower = line.lowercased()

            // Check for total keywords
            if lower.contains("total") || lower.contains("grand total") || lower.contains("jumlah") || lower.contains("bayar") {
                if let amt = extractLargestNumber(from: line) {
                    if amt > detectedTotal {
                        detectedTotal = amt
                    }
                }
                continue
            }

            // Skip common metadata headers
            if lower.contains("tanggal") || lower.contains("date") || lower.contains("kasir") || lower.contains("struk") || lower.contains("terima kasih") || lower.contains("pajak") || lower.contains("tax") {
                continue
            }

            // Look for item line (e.g. "Ice Latte 35.000" or "Nasi Goreng Rp 28.000")
            if let amt = extractNumber(from: line), amt > 1000 {
                // Remove price part to get item name
                let name = line.replacingOccurrences(of: amountRegex, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "rp", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))

                if !name.isEmpty && name.count > 2 {
                    items.append(ScannedReceiptItem(name: name, price: amt))
                }
            }
        }

        if detectedTotal == 0 {
            detectedTotal = items.reduce(0) { $0 + $1.price }
        }

        if merchant.count < 3 || merchant.lowercased().contains("welcome") {
            merchant = "Struk Belanja"
        }

        return ReceiptScanResult(
            merchantName: merchant,
            items: items,
            totalAmount: detectedTotal,
            rawLines: lines
        )
    }

    private func extractLargestNumber(from text: String) -> Double? {
        let pattern = #"[0-9]+(?:[.,][0-9]{3})*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        var maxVal: Double?
        for match in results {
            let numStr = nsString.substring(with: match.range).replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
            if let val = Double(numStr) {
                if maxVal == nil || val > (maxVal ?? 0) {
                    maxVal = val
                }
            }
        }
        return maxVal
    }

    private func extractNumber(from text: String) -> Double? {
        let pattern = #"[0-9]+(?:[.,][0-9]{3})*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        if let lastMatch = results.last {
            let numStr = nsString.substring(with: lastMatch.range).replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
            return Double(numStr)
        }
        return nil
    }

    // Demo sample receipt generator for smooth presentation during mini hackathon
    func reportImageLoadingError() {
        scanID = UUID()
        scanResult = nil
        isScanning = false
        errorMessage = "Foto belum bisa dibuka. Pilih foto lain atau gunakan kamera."
    }

    func loadDemoReceipt() {
        scanID = UUID()
        isScanning = false
        errorMessage = nil
        let demoItems: [ScannedReceiptItem] = [
            ScannedReceiptItem(name: "Ayam Bakar Madu", price: 42_000),
            ScannedReceiptItem(name: "Es Teh Manis", price: 8_000),
            ScannedReceiptItem(name: "Tempe Mendoan", price: 15_000),
            ScannedReceiptItem(name: "Nasi Putih", price: 7_000)
        ]
        self.scanResult = ReceiptScanResult(
            merchantName: "Warung Rasa Nusantara",
            items: demoItems,
            totalAmount: 72_000,
            rawLines: ["Warung Rasa Nusantara", "Ayam Bakar Madu 42.000", "Es Teh Manis 8.000", "Tempe Mendoan 15.000", "Nasi Putih 7.000", "TOTAL Rp 72.000"]
        )
    }
}
