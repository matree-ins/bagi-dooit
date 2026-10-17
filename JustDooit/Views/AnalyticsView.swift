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
            Text("Pengeluaran per Kategori")
                .font(.headline)

            let categoryMap = computeCategoryTotals()

            if categoryMap.isEmpty {
                Text("Belum ada data pengeluaran.")
                    .font(.footnote)
                    .foregroundStyle(BagiTheme.muted)
            } else {
                let total = max(1, expenseStore.totalExpensesAllTime)
                VStack(spacing: 12) {
                    ForEach(categoryMap.sorted(by: { $0.value > $1.value }), id: \.key) { cat, amount in
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

    private func computeCategoryTotals() -> [ExpenseCategory: Double] {
        var map: [ExpenseCategory: Double] = [:]
        for exp in expenseStore.expenses {
            map[exp.category, default: 0] += exp.amount
        }
        return map
    }

}
