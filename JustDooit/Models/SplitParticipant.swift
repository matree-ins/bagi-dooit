import Foundation

struct SplitParticipant: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var phoneNumber: String
    var isPaid: Bool = false

    var cleanedPhone: String {
        var digits = phoneNumber.filter { "0123456789+".contains($0) }
        if digits.hasPrefix("0") {
            digits = "62" + digits.dropFirst()
        } else if digits.hasPrefix("+") {
            digits = String(digits.dropFirst())
        }
        return digits
    }

    init(id: UUID = UUID(), name: String, phoneNumber: String, isPaid: Bool = false) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.isPaid = isPaid
    }

    enum CodingKeys: String, CodingKey {
        case id, name, phoneNumber, isPaid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
        self.isPaid = try container.decodeIfPresent(Bool.self, forKey: .isPaid) ?? false
    }
}
