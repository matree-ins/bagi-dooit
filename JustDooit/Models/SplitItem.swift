import Foundation

struct SplitItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var price: Double
    var quantity: Int = 1
    var assignedParticipantIds: Set<UUID> = []

    var totalPrice: Double {
        price * Double(max(1, quantity))
    }

    init(id: UUID = UUID(), name: String, price: Double, quantity: Int = 1, assignedParticipantIds: Set<UUID> = []) {
        self.id = id
        self.name = name
        self.price = price
        self.quantity = max(1, quantity)
        self.assignedParticipantIds = assignedParticipantIds
    }

    enum CodingKeys: String, CodingKey {
        case id, name, price, quantity, assignedParticipantIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.price = try container.decode(Double.self, forKey: .price)
        self.quantity = max(1, try container.decodeIfPresent(Int.self, forKey: .quantity) ?? 1)
        self.assignedParticipantIds = try container.decodeIfPresent(Set<UUID>.self, forKey: .assignedParticipantIds) ?? []
    }
}
