import SwiftUI

struct BudgetAdjustmentSheet: View {
    var expenseStore: ExpenseStore
    @Environment(\.dismiss) var dismiss
    @State private var currentLimit: Double = 150_000

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Target Batas Pengeluaran Harian")
                        .font(.headline)
                    Text("Bandingkan anggaran ini dengan rata-rata harian dari catatan pengeluaran bulan ini.")
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                VStack(spacing: 12) {
                    Text(CurrencyFormatter.format(currentLimit))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(BagiTheme.primary)

                    Slider(value: $currentLimit, in: 25_000...500_000, step: 25_000)
                        .padding(.horizontal, 24)

                    HStack {
                        Text("Rp 25.000 (Sangat Hemat)")
                            .font(.footnote)
                            .foregroundStyle(BagiTheme.muted)
                        Spacer()
                        Text("Rp 500.000")
                            .font(.footnote)
                            .foregroundStyle(BagiTheme.muted)
                    }
                    .padding(.horizontal, 24)
                }
                .padding()
                .background(BagiTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
                .padding(.horizontal)

                Spacer()

                Button(action: {
                    expenseStore.dailyBudgetLimit = currentLimit
                    dismiss()
                }) {
                    Text("Simpan Target Budget")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(BagiTheme.action)
                        .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Atur Target Hemat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
            .onAppear {
                currentLimit = expenseStore.dailyBudgetLimit
            }
        }
    }
}
