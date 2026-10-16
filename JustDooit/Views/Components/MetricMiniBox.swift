import SwiftUI

struct MetricMiniBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.footnote, weight: .medium))
                .foregroundStyle(BagiTheme.muted)
            Text(value)
                .font(.system(.footnote, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(BagiTheme.soft)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

