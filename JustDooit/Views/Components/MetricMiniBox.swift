import SwiftUI

struct MetricMiniBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote).foregroundStyle(BagiTheme.muted)
            Text(value).font(.subheadline.bold()).monospacedDigit()
                .foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(BagiTheme.soft, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
