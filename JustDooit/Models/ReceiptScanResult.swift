import Foundation

struct ReceiptScanResult: Equatable {
    var merchantName: String
    var items: [ScannedReceiptItem]
    var totalAmount: Double
    var rawLines: [String]
}

