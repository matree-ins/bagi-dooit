import Foundation

// Spoken by Siri, which runs in English because Siri does not support Indonesian.
enum SiriEntryError: LocalizedError {
    case invalidAmount
    case invalidTitle
    case invalidParticipants
    case invalidItems
    case invalidCharges
    case invalidAssignments
    case invalidBill

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Say a whole rupiah amount above zero, up to one billion."
        case .invalidTitle:
            return "Say a bill name between one and 120 characters."
        case .invalidParticipants:
            return "Say one to nine different friend names, separated by and. You are included automatically."
        case .invalidItems:
            return "I couldn't read the items. Say each item with quantity and unit price, for example: fried rice quantity two unit price twenty five thousand, then iced tea quantity three unit price five thousand. Use different item names."
        case .invalidCharges:
            return "I couldn't read the extras. For example: tax ten percent, then delivery twelve thousand. Say none if there are no extras. A discount cannot exceed the subtotal."
        case .invalidAssignments:
            return "I couldn't match the items to people. Say each item once, for example: fried rice for Budi one and Siti one, then iced tea for me one and Budi one and Siti one. The numbers must add up to each item's quantity."
        case .invalidBill:
            return "The bill can't be saved yet. Check the people and amounts, then try again."
        }
    }
}
