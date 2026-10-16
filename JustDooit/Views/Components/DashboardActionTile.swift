import SwiftUI

struct DashboardActionTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(BagiTheme.primary)
                    .frame(width: 48, height: 48)
                    .background(BagiTheme.soft, in: .rect(cornerRadius: BagiTheme.radius))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(BagiTheme.ink)
                    Text(subtitle).font(.subheadline).foregroundStyle(BagiTheme.muted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.bold())
                    .foregroundStyle(BagiTheme.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BagiTheme.surface, in: .rect(cornerRadius: BagiTheme.radius))
        }
        .buttonStyle(.plain)
    }
}
