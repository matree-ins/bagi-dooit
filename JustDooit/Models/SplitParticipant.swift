import Foundation

struct SplitParticipant: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var phoneNumber: String

    var cleanedPhone: String {
        var digits = phoneNumber.filter { "0123456789+".contains($0) }
        if digits.hasPrefix("0") {
            digits = "62" + digits.dropFirst()
        } else if digits.hasPrefix("+") {
            digits = String(digits.dropFirst())
        }
        return digits
    }
}

