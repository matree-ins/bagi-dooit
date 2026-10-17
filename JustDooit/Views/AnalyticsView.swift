//
//  AnalyticsView.swift
//  JustDooit
//

import SwiftUI

struct AnalyticsView: View {
    @ObservedObject var expenseStore: ExpenseStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Feature 2 deep dive card
                    FinancialBehaviorCard(expenseStore: expenseStore)

                    // Category Breakdown
                    categoryBreakdownSection

                }
                .padding()
                .padding(.bottom, 30)
            }
            .bagiScreen()
            .navigationTitle("Tips hemat")
            .refreshable {
                expenseStore.savingsAI.refresh(for: expenseStore.currentAdvice, force: true)
            }
        }
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Kategori bulan ini")
                .font(.headline)

            let advice = expenseStore.currentAdvice
            let categoryMap = advice.categoryTotals

            if categoryMap.isEmpty {
                Text("Belum ada data pengeluaran.")
                    .font(.footnote)
                    .foregroundStyle(BagiTheme.muted)
            } else {
                let total = max(1, advice.totalAmount)
                VStack(spacing: 12) {
                    ForEach(categoryMap.sorted(by: { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }), id: \.key) { cat, amount in
                        VStack(spacing: 6) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                        .foregroundStyle(cat.color)
                                    Text(cat.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                Spacer()
                                Text(CurrencyFormatter.format(amount))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }

                            // Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(BagiTheme.soft)
                                        .frame(height: 8)

                                    Capsule()
                                        .fill(cat.color)
                                        .frame(width: geo.size.width * CGFloat(amount / total), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding()
                .background(BagiTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
            }
        }
    }

}
