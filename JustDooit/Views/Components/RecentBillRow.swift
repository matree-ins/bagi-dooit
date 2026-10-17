import SwiftUI

struct RecentBillRow: View {
    let session: SplitBillSession

    private var unpaidCount: Int {
        session.participants.filter { $0.name != "Saya" && !$0.isPaid }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    title
                    Spacer(minLength: 0)
                    amount
                }
                VStack(alignment: .leading, spacing: 6) { title; amount }
            }
            Text(session.date, format: .dateTime.day().month(.abbreviated))
                .font(.footnote).foregroundStyle(BagiTheme.muted)
            if !session.participants.isEmpty {
                Text(session.participants.map(\.name).joined(separator: ", "))
                    .font(.subheadline).foregroundStyle(BagiTheme.muted)
                    .lineLimit(2)
            }
            Label(unpaidCount > 0 ? "Menunggu \(unpaidCount) pembayaran" : "Semua lunas",
                  systemImage: unpaidCount > 0 ? "clock" : "checkmark.circle.fill")
                .font(.footnote.bold())
                .foregroundStyle(unpaidCount > 0 ? BagiTheme.warning : BagiTheme.success)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BagiTheme.surface, in: .rect(cornerRadius: BagiTheme.radius))
        .overlay(RoundedRectangle(cornerRadius: BagiTheme.radius).strokeBorder(BagiTheme.border, lineWidth: 0.5))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        Text(session.title.isEmpty ? "Tagihan bersama" : session.title)
            .font(.headline).foregroundStyle(BagiTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
    private var amount: some View {
        Text(CurrencyFormatter.format(session.total))
            .font(.headline).monospacedDigit().foregroundStyle(BagiTheme.ink)
            .fixedSize()
    }
}
