import Foundation

struct SiriReceiptItem {
    let name: String
    let quantity: Int
    let unitPrice: Double
    var total: Double { Double(quantity) * unitPrice }
}
