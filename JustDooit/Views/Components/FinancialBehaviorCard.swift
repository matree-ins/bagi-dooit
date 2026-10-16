//
//  FinancialBehaviorCard.swift
//  JustDooit
//

import SwiftUI

struct FinancialBehaviorCard: View {
    @ObservedObject var expenseStore: ExpenseStore
    @State private var isExpanded: Bool = false
    @State private var showBudgetSheet: Bool = false

    var body: some View {
        let advice = expenseStore.currentAdvice

        VStack(alignment: .leading, spacing: 14) {
            // Header: Title & Status Badge
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("AI Behaviour Advisor")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: advice.status.icon)
                    Text(advice.status.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(advice.status.badgeColor.opacity(0.15))
                .foregroundStyle(advice.status.badgeColor)
                .clipShape(Capsule())
            }

            // Headline
            Text(advice.headline)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            // Detailed Advice
            Text(advice.detailedAdvice)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            // 3-Day Metrics Grid
            HStack(spacing: 12) {
                MetricMiniBox(
                    title: "Total 3 Hari",
                    value: CurrencyFormatter.format(advice.threeDayTotal),
                    color: .primary
                )

                MetricMiniBox(
                    title: "Rata-rata/Hari",
                    value: CurrencyFormatter.format(advice.threeDayDailyAverage),
                    color: advice.status.badgeColor
                )

                MetricMiniBox(
                    title: "Batas Aman/Hari",
                    value: CurrencyFormatter.format(advice.safeDailyLimit),
                    color: .secondary
                )
            }

            // Expandable Action Steps
            if !advice.actionPlan.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text(isExpanded ? "Sembunyikan Action Plan" : "Lihat Rekomendasi Tindakan")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }

                    if isExpanded {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(advice.actionPlan, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(advice.status.badgeColor)
                                        .padding(.top, 2)
                                    Text(tip)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }

            // Interactive Budget Adjuster Button
            HStack {
                Button(action: { showBudgetSheet = true }) {
                    Label("Ubah Target Budget Harian", systemImage: "slider.horizontal.3")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(advice.status.badgeColor.opacity(0.3), lineWidth: 1.5)
        )
        .sheet(isPresented: $showBudgetSheet) {
            BudgetAdjustmentSheet(expenseStore: expenseStore)
        }
    }
}

private struct MetricMiniBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct BudgetAdjustmentSheet: View {
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                VStack(spacing: 12) {
                    Text(CurrencyFormatter.format(currentLimit))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)

                    Slider(value: $currentLimit, in: 25_000...500_000, step: 25_000)
                        .padding(.horizontal, 24)

                    HStack {
                        Text("Rp 25.000 (Sangat Hemat)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Rp 500.000")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
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
