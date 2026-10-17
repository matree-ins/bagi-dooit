import SwiftUI

struct FinancialBehaviorCard: View {
    @ObservedObject var expenseStore: ExpenseStore
    @State private var isExpanded = false
    @State private var showBudgetSheet = false

    var body: some View {
        let advice = expenseStore.currentAdvice
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Label("Pengeluaran bulan ini", systemImage: "sparkles")
                        .font(.headline)
                    Spacer(minLength: 8)
                    FinancialStatusBadge(status: advice.status)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label("Pengeluaran bulan ini", systemImage: "sparkles")
                        .font(.headline)
                    FinancialStatusBadge(status: advice.status)
                }
            }
            Text(advice.headline).font(.subheadline.bold())
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Text(CurrencyFormatter.format(advice.totalAmount))
                    .font(.title2.bold())
                Text("Anggaran sampai hari ini \(CurrencyFormatter.format(advice.periodBudget))")
                    .font(.footnote).foregroundStyle(BagiTheme.muted)
                if let category = advice.topCategory {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kategori terbesar: \(category.rawValue)")
                        Text(CurrencyFormatter.format(advice.topCategoryAmount))
                    }
                    .font(.footnote).foregroundStyle(BagiTheme.muted)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup("Lihat rincian", isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Bulan ini")
                        .font(.footnote).foregroundStyle(BagiTheme.muted)
                    Text(advice.detailedAdvice)
                        .font(.subheadline)
                        .foregroundStyle(BagiTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), alignment: .leading)], spacing: 12) {
                        MetricMiniBox(title: "Rata-rata / hari", value: CurrencyFormatter.format(advice.dailyAverage), color: advice.status.badgeColor)
                        MetricMiniBox(title: "Batas harian", value: CurrencyFormatter.format(advice.safeDailyLimit), color: BagiTheme.ink)
                    }
                    Divider()
                    SavingsAISection(service: expenseStore.savingsAI, advice: advice)
                }
                .padding(.top, 12)
            }
            .font(.subheadline)
            Button { showBudgetSheet = true } label: {
                Label("Atur anggaran harian", systemImage: "slider.horizontal.3")
                    .font(.subheadline)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
        .foregroundStyle(BagiTheme.ink)
        .padding(BagiTheme.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BagiTheme.surface, in: .rect(cornerRadius: BagiTheme.radius))
        .sheet(isPresented: $showBudgetSheet) {
            BudgetAdjustmentSheet(expenseStore: expenseStore)
        }
    }
}
