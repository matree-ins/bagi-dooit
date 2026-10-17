import SwiftUI

struct FinancialStatusBadge: View {
    let status: FinancialStatus

    private var color: Color {
        switch status {
        case .insufficientData: return BagiTheme.muted
        case .hemat: return BagiTheme.success
        case .normal: return BagiTheme.primary
        case .warning: return BagiTheme.warning
        case .alert: return BagiTheme.danger
        }
    }

    var body: some View {
        Label(status.rawValue, systemImage: status.icon)
            .font(.footnote.weight(.medium))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.1), in: .capsule)
    }
}
