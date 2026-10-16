import SwiftUI

struct SplitBillSummaryCard: View {
    @Binding var session: SplitBillSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "receipt.fill")
                    .foregroundStyle(BagiTheme.primary)
                TextField("Nama Tagihan / Acara", text: $session.title)
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subtotal")
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                    Text(CurrencyFormatter.format(session.subtotal))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Tagihan")
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                    Text(CurrencyFormatter.format(session.total))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(BagiTheme.primary)
                }
            }
        }
        .padding(16)
        .background(BagiTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
    
    }
}
