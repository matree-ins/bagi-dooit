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
        isScanning = true

        guard let cgImage = image.cgImage else {
            isScanning = false
            errorMessage = "Format foto tidak didukung. Silakan coba lagi dengan foto yang berbeda."
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] (req, err) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.scanID == currentScanID else { return }
                self.isScanning = false

                if let err = err {
                    self.scanResult = nil
                    self.errorMessage = "Gagal memindai teks: \(err.localizedDescription). Silakan coba lagi."
                    return
                }

                guard let observations = req.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    self.scanResult = nil
                    self.errorMessage = "Tidak ada struk atau teks terdeteksi dari foto ini. Silakan coba lagi dengan memastikan seluruh struk berada di dalam bingkai."
                    return
                }

                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                guard !lines.isEmpty else {
                    self.scanResult = nil
                    self.errorMessage = "Teks struk tidak terbaca dengan jelas. Silakan coba lagi dengan pencahayaan yang cukup."
                    return
                }

                let parsed = self.parseObservations(observations, fallbackLines: lines)
                if parsed.items.isEmpty {
                    self.scanResult = nil
                    self.errorMessage = "Kamera tidak dapat mendeteksi menu atau harga dari foto ini. Silakan coba lagi dengan foto struk yang lebih tajam, atau gunakan Input Manual."
                    return
                }

                self.scanResult = parsed
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
                    self.scanResult = nil
                    self.errorMessage = "Terjadi kesalahan saat memproses gambar: \(error.localizedDescription). Silakan coba lagi."
                }
            }
        }
    }

    private struct OCRToken {
        let text: String
        let bbox: CGRect
        var minX: CGFloat { bbox.minX }
        var midX: CGFloat { bbox.midX }
        var maxX: CGFloat { bbox.maxX }
        var minY: CGFloat { bbox.minY }
        var midY: CGFloat { bbox.midY }
        var maxY: CGFloat { bbox.maxY }
    }

    private func parseObservations(_ observations: [VNRecognizedTextObservation], fallbackLines: [String]) -> ReceiptScanResult {
        let tokens: [OCRToken] = observations.compactMap { obs in
            guard let text = obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return OCRToken(text: text, bbox: obs.boundingBox)
        }

        guard !tokens.isEmpty else {
            return parseReceiptLines(fallbackLines)
        }

        // 1. Merchant Detection: Check top tokens
        var detectedMerchant = "Struk Belanja"
        if tokens.contains(where: { $0.text.uppercased().contains("SOLARIA") }) {
            detectedMerchant = "SOLARIA"
        } else {
            let topTokens = tokens.filter { $0.midY > 0.45 }.sorted { $0.midY > $1.midY }
            for t in topTokens {
                if isHeaderMetadata(t.text) || isFooterMetadata(t.text) { continue }
                if parseAmount(t.text) != nil { continue }
                if Int(t.text) != nil { continue }
                if t.text.count >= 3 {
                    detectedMerchant = t.text
                    break
                }
            }
        }

        // 2. Identify Total Amount, Total Item Count, and Footer Boundary
        var detectedTotal: Double = 0
        var totalItemCount: Int? = nil
        var footerBoundaryY: CGFloat = 0.0

        for t in tokens {
            if isFooterMetadata(t.text) {
                if t.midY > footerBoundaryY {
                    footerBoundaryY = t.midY
                }
                if t.text.lowercased().contains("items:") || t.text.lowercased().contains("item:") {
                    let nums = t.text.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
                    if let n = nums.first, n > 0 && n <= 100 {
                        totalItemCount = n
                    }
                }
            }
        }

        // Total extraction
        if let totalToken = tokens.first(where: {
            let l = $0.text.lowercased().trimmingCharacters(in: .punctuationCharacters)
            return l == "total" || l == "grand total" || l == "jumlah bayar"
        }) {
            let amountsNearTotal = tokens.compactMap { t -> (amt: Double, dist: CGFloat)? in
                guard let amt = parseAmount(t.text) else { return nil }
                let dy = abs(t.midY - totalToken.midY)
                return dy < 0.05 ? (amt, dy) : nil
            }.sorted { $0.dist < $1.dist }
            if let best = amountsNearTotal.first {
                detectedTotal = best.amt
            }
        }

        if detectedTotal == 0 {
            for t in tokens {
                if let amt = parseAmount(t.text), amt > detectedTotal {
                    detectedTotal = amt
                }
            }
        }

        // 3. Menu Candidates: Left column (minX < 0.45), above footer metadata
        let menuTokens = tokens.filter { t in
            t.minX < 0.45 &&
            t.midY > (footerBoundaryY - 0.02) &&
            !isHeaderMetadata(t.text) &&
            !isFooterMetadata(t.text) &&
            t.text.uppercased() != detectedMerchant.uppercased() &&
            Int(t.text) == nil &&
            parseAmount(t.text) == nil &&
            t.text.count >= 3
        }.sorted { $0.midY > $1.midY }

        // 4. Price Candidates: Right column (minX >= 0.50), above footer metadata
        var priceCandidates = tokens.filter { t in
            t.minX >= 0.50 &&
            t.midY > (footerBoundaryY - 0.02) &&
            !isHeaderMetadata(t.text) &&
            !isFooterMetadata(t.text)
        }.compactMap { t -> (amt: Double, token: OCRToken)? in
            guard let amt = parseAmount(t.text) else { return nil }
            return (amt, t)
        }.sorted { $0.token.midY > $1.token.midY }

        // 5. Filter out Subtotal from prices
        // (A price that equals the sum of the preceding item prices is the subtotal)
        for i in 1..<priceCandidates.count {
            let sumPrev = priceCandidates[0..<i].reduce(0) { $0 + $1.amt }
            if abs(sumPrev - priceCandidates[i].amt) < 10.0 {
                priceCandidates.remove(at: i)
                break
            }
        }

        // Cap price candidates to menu count if needed
        if priceCandidates.count > menuTokens.count && !menuTokens.isEmpty {
            priceCandidates = Array(priceCandidates.prefix(menuTokens.count))
        }

        // 6. Calculate quantities
        var quantities = Array(repeating: 1, count: menuTokens.count)

        // Check if item name itself has quantity prefix, e.g. "2 EB Ayam"
        for i in 0..<menuTokens.count {
            let name = menuTokens[i].text
            let qtyPattern = #"^(\d{1,2})\s*(?:x\s*)?"#
            if let match = name.range(of: qtyPattern, options: .regularExpression) {
                let qtyStr = name[match].replacingOccurrences(of: "x", with: "").trimmingCharacters(in: .whitespaces)
                if let parsedQty = Int(qtyStr), parsedQty > 0 && parsedQty <= 50 {
                    quantities[i] = parsedQty
                }
            }
        }

        // If target total items is known (e.g. ITEMS: 5) and sum of quantities is less:
        let currentQtySum = quantities.reduce(0, +)
        if let targetTotal = totalItemCount, targetTotal > currentQtySum, !priceCandidates.isEmpty {
            let extra = targetTotal - currentQtySum
            // Allocate extra to highest priced item (e.g. EB Ayam Teriyaki total 60.000 vs 30.000 unit price)
            var bestIdx = 0
            var highestPrice = 0.0
            for (idx, p) in priceCandidates.enumerated() {
                if p.amt > highestPrice {
                    highestPrice = p.amt
                    bestIdx = idx
                }
            }
            quantities[bestIdx] += extra
        }

        // 7. Pair menus with prices
        var scannedItems: [ScannedReceiptItem] = []
        let pairCount = min(menuTokens.count, priceCandidates.count)
        for i in 0..<pairCount {
            var name = menuTokens[i].text
            name = name.replacingOccurrences(of: "Ayarn", with: "Ayam")

            // Remove leading qty if present in name string
            let qtyPattern = #"^(\d{1,2})\s*(?:x\s*)?"#
            if let match = name.range(of: qtyPattern, options: .regularExpression) {
                name.removeSubrange(match)
            }
            name = name.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))

            let rawPrice = priceCandidates[i].amt
            let qty = quantities[i]
            var unitPrice = rawPrice
            if qty > 1 {
                unitPrice = round(rawPrice / Double(qty))
            }

            scannedItems.append(ScannedReceiptItem(name: name, price: unitPrice, quantity: qty))
        }

        // Fallback to line parser if spatial separation didn't capture items
        if scannedItems.isEmpty {
            let fallbackResult = parseReceiptLines(fallbackLines)
            scannedItems = fallbackResult.items
            if detectedMerchant == "Struk Belanja" {
                detectedMerchant = fallbackResult.merchantName
            }
        }

        if detectedTotal == 0 {
            detectedTotal = scannedItems.reduce(0) { $0 + ($1.price * Double(max(1, $1.quantity))) }
        }

        return ReceiptScanResult(
            merchantName: detectedMerchant,
            items: scannedItems,
            totalAmount: detectedTotal,
            rawLines: fallbackLines
        )
    }

    private func parseReceiptLines(_ lines: [String]) -> ReceiptScanResult {
        var merchant = "Struk Belanja"
        var items: [ScannedReceiptItem] = []
        var detectedTotal: Double = 0

        let amountRegex = #"(\d{1,3}(?:[.,]\d{3})*|\d{3,7})"#

        for line in lines {
            let lower = line.lowercased()

            // Skip table numbers and metadata headers
            if isHeaderMetadata(line) {
                continue
            }

            // Check for total keywords
            if lower.contains("total") || lower.contains("grand total") || lower.contains("jumlah") || lower.contains("bayar") {
                if let amt = extractLargestNumber(from: line) {
                    if amt > detectedTotal {
                        detectedTotal = amt
                    }
                }
                continue
            }

            // Skip footer metadata
            if isFooterMetadata(line) {
                continue
            }

            // Set merchant name from early non-metadata line
            if merchant == "Struk Belanja" && !line.isEmpty && line.count > 2 && parseAmount(line) == nil && Int(line) == nil {
                merchant = line
                continue
            }

            // Look for item line (e.g. "Ice Latte 35.000" or "Nasi Goreng Rp 28.000")
            if let amt = extractNumber(from: line), amt > 1000 {
                var name = line.replacingOccurrences(of: amountRegex, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "rp", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))

                name = name.replacingOccurrences(of: "Ayarn", with: "Ayam")

                var qty = 1
                let qtyPattern = #"^(\d{1,2})\s*(?:x\s*)?"#
                if let match = name.range(of: qtyPattern, options: .regularExpression) {
                    let qtyStr = name[match].replacingOccurrences(of: "x", with: "").trimmingCharacters(in: .whitespaces)
                    if let parsedQty = Int(qtyStr), parsedQty > 0 && parsedQty <= 50 {
                        qty = parsedQty
                        name.removeSubrange(match)
                        name = name.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                    }
                }

                var unitPrice = amt
                if qty > 1 && amt >= Double(qty) * 1000 && amt.truncatingRemainder(dividingBy: Double(qty)) == 0 {
                    unitPrice = amt / Double(qty)
                }

                if !name.isEmpty && name.count > 2 && !isHeaderMetadata(name) && !isFooterMetadata(name) {
                    items.append(ScannedReceiptItem(name: name, price: unitPrice, quantity: qty))
                }
            }
        }

        if detectedTotal == 0 {
            detectedTotal = items.reduce(0) { $0 + ($1.price * Double(max(1, $1.quantity))) }
        }

        return ReceiptScanResult(
            merchantName: merchant,
            items: items,
            totalAmount: detectedTotal,
            rawLines: lines
        )
    }

    private func parseAmount(_ str: String) -> Double? {
        let cleaned = str.replacingOccurrences(of: "rp", with: "", options: .caseInsensitive)
                         .trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?$"#
        if cleaned.range(of: pattern, options: .regularExpression) != nil {
            let raw = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
            if let val = Double(raw), val >= 500 {
                return val
            }
        }
        return nil
    }

    private func isHeaderMetadata(_ text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = [
            "date", "tanggal", "receipt no", "cashier", "kasir", "waiter", "server",
            "customer", "dine in", "take away", "takeout", "meja", "table", "pax",
            "order #", "trx", "transaksi", "welcome", "selamat datang", "jl.", "jalan",
            "telp", "phone", "wib", "wita", "wit", "no customer"
        ]
        for kw in keywords {
            if lower.contains(kw) { return true }
        }
        if let _ = Int(text), text.count <= 3 { return true }
        return false
    }

    private func isFooterMetadata(_ text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = [
            "items:", "item:", "pb1", "pajak", "tax", "ppn", "vat", "service", "sc ",
            "rounding", "pembulatan", "before rounding", "subtotal", "sub total",
            "total", "grand total", "mandiri", "bca", "bni", "bri", "qris", "gopay",
            "ovo", "dana", "shopeepay", "signature", "tanda tangan", "kembalian",
            "kembali", "change", "kartu", "debit", "kredit", "tunai", "cash "
        ]
        for kw in keywords {
            if lower.contains(kw) { return true }
        }
        return false
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

    func reportImageLoadingError() {
        scanID = UUID()
        scanResult = nil
        isScanning = false
        errorMessage = "Foto tidak dapat dimuat. Silakan coba lagi atau pilih foto struk yang lain."
    }

    func loadDemoReceipt() {
        loadKedaiSenjaReceipt()
    }

    // Demo / Viewfinder ticket matching realistic capture
    func loadKedaiSenjaReceipt() {
        scanID = UUID()
        isScanning = true
        errorMessage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }
            self.isScanning = false
            let demoItems: [ScannedReceiptItem] = [
                ScannedReceiptItem(name: "Nasi Goreng", price: 30_000, quantity: 2),
                ScannedReceiptItem(name: "Es Teh", price: 10_000, quantity: 3),
                ScannedReceiptItem(name: "Kentang", price: 30_000, quantity: 1)
            ]
            self.scanResult = ReceiptScanResult(
                merchantName: "KEDAI SENJA",
                items: demoItems,
                totalAmount: 138_000,
                rawLines: ["KEDAI SENJA", "16 Okt 2026 • Meja 04", "2 Nasi Goreng 60.000", "3 Es Teh 30.000", "1 Kentang 30.000", "TOTAL Rp138.000"]
            )
        }
    }
}
