import Foundation

struct ScannedReceiptItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var price: Double
}

