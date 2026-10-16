import SwiftUI

struct BudgetAdjustmentSheet: View {
    @ObservedObject var expenseStore: ExpenseStore
    @Environment(\.presentationMode) var presentationMode
    @State private var currentLimit: Double = 150_000

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Target Batas Pengeluaran Harian")
                        .font(.headline)
                    Text("Advisor akan menghitung apakah kamu perlu 'Lebih Hemat' berdasarkan batas ini terhadap pengeluaran 3 hari terakhir.")
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
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Simpan Target Budget")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(BagiTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Atur Target Hemat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                currentLimit = expenseStore.dailyBudgetLimit
            }
        }
    }
}
