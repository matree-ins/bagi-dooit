import Foundation

struct SavingsSuggestion: Equatable {
    let summary: String
    let actions: [String]

    var isValid: Bool {
        let texts = [summary] + actions
        return (2...3).contains(actions.count) && Set(actions).count == actions.count
            && !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && summary.count <= 300 && actions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 200 }
            && texts.allSatisfy { $0.rangeOfCharacter(from: .decimalDigits) == nil }
    }

}
