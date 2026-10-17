import SwiftUI

struct FinancialStatusBadge: View {
    let status: FinancialStatus

    var body: some View {
        Label(status.rawValue, systemImage: status.icon)
            .font(.footnote.weight(.medium))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(status.badgeColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(status.badgeColor.opacity(0.1), in: .capsule)
    }
}
