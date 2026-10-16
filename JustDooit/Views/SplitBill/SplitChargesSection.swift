import SwiftUI

struct SplitChargesSection: View {
    @Binding var session: SplitBillSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pajak & layanan", systemImage: "percent")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    Text("Pajak / PPN (\(Int(session.taxPercentage))%)")
                        .font(.footnote)
                    Spacer()
                    Text(CurrencyFormatter.format(session.taxAmount))
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                }
                Slider(value: $session.taxPercentage, in: 0...20, step: 1)

                HStack {
                    Text("Service Charge (\(Int(session.servicePercentage))%)")
                        .font(.footnote)
                    Spacer()
                    Text(CurrencyFormatter.format(session.serviceAmount))
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                }
                Slider(value: $session.servicePercentage, in: 0...15, step: 1)
            }
            .padding()
            .background(BagiTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
        }
    
    }
}
