import Foundation

struct SplitBillCharge: Identifiable, Codable {
    var id = UUID()
    let name: String
    let value: Double
    let kind: SplitBillChargeKind

    func amount(afterDiscount subtotal: Double) -> Double {
        switch kind {
        case .fixed: return value
        case .percentage: return (subtotal * value / 100).rounded()
        }
    }
}
