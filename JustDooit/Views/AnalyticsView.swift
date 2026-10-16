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

                    // Educational Hemat Tips
                    hematTipsSection
                }
                .padding()
                .padding(.bottom, 30)
            }
            .navigationTitle("Analisis & Tips Hemat")
        }
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pengeluaran per Kategori")
                .font(.headline)

            let categoryMap = computeCategoryTotals()

            if categoryMap.isEmpty {
                Text("Belum ada data pengeluaran.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                                        .fill(Color(UIColor.tertiarySystemBackground))
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
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
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

    private var hematTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Tips Hemat Finansial Cerdas")
                    .font(.headline)
            }

            VStack(spacing: 10) {
                tipRow(
                    icon: "clock.badge.checkmark",
                    title: "Aturan 48 Jam",
                    desc: "Tunda pembelian barang non-esensial selama 2 hari sebelum checkout untuk mencegah impulsive buying."
                )

                tipRow(
                    icon: "cup.and.saucer.fill",
                    title: "Substitusi Kopi & Jajan",
                    desc: "Buat kopi sendiri di rumah atau kantor 3 kali seminggu, hemat hingga Rp 300.000/bulan."
                )

                tipRow(
                    icon: "chart.line.downtrend.xyaxis",
                    title: "Evaluasi 3 Hari Rutin",
                    desc: "Pantau pengeluaran 3 harian untuk mendeteksi lonjakan biaya sebelum membengkak di akhir bulan."
                )
            }
        }
    }

    private func tipRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(desc)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
