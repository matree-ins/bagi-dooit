import Foundation

struct SplitItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var price: Double
    var assignedParticipantIds: Set<UUID> = []
}

