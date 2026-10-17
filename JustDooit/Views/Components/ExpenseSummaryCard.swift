import SwiftUI

struct ExpenseSummaryCard: View {
    let today: Double
    let total: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Pengeluaran hari ini", systemImage: "sun.max")
                .font(.subheadline)
            Text(CurrencyFormatter.format(today))
                .font(.largeTitle.bold())
                .monospacedDigit()
                .contentTransition(.numericText())
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline) {
                Text("Total tercatat")
                Spacer(minLength: 12)
                Text(CurrencyFormatter.format(total)).bold().monospacedDigit()
            }
            .font(.subheadline)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BagiTheme.action, in: .rect(cornerRadius: BagiTheme.radius))
    }
}
