//
//  AnalyticsView.swift
//  JustDooit
//

import SwiftUI

struct AnalyticsView: View {
    var expenseStore: ExpenseStore
    var onShowOnboarding: (() -> Void)? = nil

    @State private var showProfileSheet: Bool = false
    @State private var showBudgetSheet: Bool = false

    private func formatRp(_ amount: Double) -> String {
        CurrencyFormatter.format(amount).replacingOccurrences(of: " ", with: "")
    }

    private func formatCompactAmount(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "%.1fJt", amount / 1_000_000).replacingOccurrences(of: ".0", with: "")
        } else if amount >= 1_000 {
            return String(format: "%.0frb", amount / 1_000)
        } else {
            return String(format: "%.0f", amount)
        }
    }

    var body: some View {
        let advice = expenseStore.currentAdvice

        NavigationStack {
            ZStack {
                Color(hex: "#F7F8FB")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // MARK: - Header
                        headerView
                            .padding(.top, 8)

                        // MARK: - Hero Blue Overview Card
                        heroAdviceCard(advice: advice)

                        // MARK: - Adjust Budget Button
                        adjustBudgetButton

                        // MARK: - Smart AI Advice Card
                        smartAIAdviceCard(advice: advice)

                        // MARK: - Financial Behavior Details Card
                        behaviorDetailsCard(advice: advice)

                        // MARK: - Category Breakdown Card
                        categoryBreakdownCard(advice: advice)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showProfileSheet = true }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#3A6CFF").opacity(0.12))
                                .frame(width: 36, height: 36)

                            if let firstChar = expenseStore.userName.first {
                                Text(String(firstChar).uppercased())
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(hex: "#3A6CFF"))
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#3A6CFF"))
                            }
                        }
                    }
                    .accessibilityLabel("Profil Pengguna")
                }
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView(expenseStore: expenseStore, onShowOnboarding: onShowOnboarding)
            }
            .sheet(isPresented: $showBudgetSheet) {
                BudgetAdjustmentSheet(expenseStore: expenseStore)
            }
            .refreshable {
                expenseStore.savingsAI.refresh(for: expenseStore.currentAdvice, force: true)
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tips Hemat")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            Text("Analisis pintar & kebiasaan finansialmu")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "#6B7280"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero Blue Card
    private func heroAdviceCard(advice: FinancialBehaviorAdvice) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Pengeluaran Bulan Ini")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))

                Spacer()

                // Status Badge in frosted capsule
                HStack(spacing: 5) {
                    Image(systemName: advice.status.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(advice.status.rawValue)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
            }

            Text(formatRp(advice.totalAmount))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            Text("Anggaran s.d. hari ini: \(formatRp(advice.periodBudget))")
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.9))

            // Mini stats tags
            HStack(spacing: 8) {
                miniStatTag(title: "Rata-rata/hari", value: formatCompactAmount(advice.dailyAverage))
                miniStatTag(title: "Batas harian", value: formatCompactAmount(advice.safeDailyLimit))
                if let topCat = advice.topCategory {
                    miniStatTag(title: "Terbanyak", value: topCat.rawValue)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#3A6CFF"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color(hex: "#3A6CFF").opacity(0.22), radius: 10, x: 0, y: 5)
    }

    private func miniStatTag(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Adjust Budget Button
    private var adjustBudgetButton: some View {
        Button(action: { showBudgetSheet = true }) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#3A6CFF").opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#3A6CFF"))
                }

                Text("Atur Target Anggaran Harian")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#111827"))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Smart AI Advice Card
    private func smartAIAdviceCard(advice: FinancialBehaviorAdvice) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#3A6CFF").opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#3A6CFF"))
                    }

                    Text("Saran Finansial Pintar")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: "#111827"))
                }

                Spacer()

                if expenseStore.savingsAI.isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let suggestion = expenseStore.savingsAI.suggestion {
                // Summary Box
                Text(suggestion.summary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#374151"))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#F3F4F6"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Action Plans
                VStack(alignment: .leading, spacing: 10) {
                    Text("Aksi yang Disarankan:")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#4B5563"))

                    ForEach(suggestion.actions, id: \.self) { action in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "#10B981"))
                                .padding(.top, 1)

                            Text(action)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(hex: "#1F2937"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                let fallbackActions = SavingsFallback.actions(for: advice)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Aksi yang Disarankan:")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#4B5563"))

                    ForEach(fallbackActions, id: \.self) { action in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "#3A6CFF"))
                                .padding(.top, 1)

                            Text(action)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(hex: "#1F2937"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Behavior Details Card
    private func behaviorDetailsCard(advice: FinancialBehaviorAdvice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analisis Kebiasaan Belanja")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            Text(advice.headline)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#1F2937"))

            Text(advice.detailedAdvice)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#6B7280"))
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Category Breakdown Card
    private func categoryBreakdownCard(advice: FinancialBehaviorAdvice) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Kategori Bulan Ini")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#111827"))

                Spacer()

                Text("\(advice.categoryTotals.count) kategori")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#6B7280"))
            }

            let categoryMap = advice.categoryTotals
            if categoryMap.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                    Text("Belum ada pengeluaran di bulan ini")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                let total = max(1, advice.totalAmount)
                VStack(spacing: 12) {
                    ForEach(categoryMap.sorted(by: { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }), id: \.key) { cat, amount in
                        let percentage = (amount / total) * 100
                        VStack(spacing: 6) {
                            HStack {
                                HStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(cat.color.opacity(0.12))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 14))
                                            .foregroundStyle(cat.color)
                                    }

                                    Text(cat.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(hex: "#111827"))
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    Text(formatRp(amount))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color(hex: "#111827"))

                                    Text(String(format: "%.0f%%", percentage))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(cat.color)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(cat.color.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }

                            // Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(hex: "#F3F4F6"))
                                        .frame(height: 6)

                                    Capsule()
                                        .fill(cat.color)
                                        .frame(width: geo.size.width * CGFloat(amount / total), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    AnalyticsView(expenseStore: ExpenseStore())
}
