import Foundation

struct SavingsErrorNotice: Identifiable {
    let id = UUID()
    let message: String
    var canRetry = true
}
