import Foundation

struct ScannedReceiptItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var price: Double
    var quantity: Int = 1

    var totalPrice: Double {
        price * Double(max(1, quantity))
    }

    init(id: UUID = UUID(), name: String, price: Double, quantity: Int = 1) {
        self.id = id
        self.name = name
        self.price = price
        self.quantity = max(1, quantity)
    }
}
