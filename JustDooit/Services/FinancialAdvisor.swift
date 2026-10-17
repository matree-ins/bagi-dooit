//
//  FinancialAdvisor.swift
//  JustDooit
//

import SwiftUI

enum FinancialStatus: String {
    case insufficientData = "Belum cukup data"
    case hemat = "Di bawah anggaran"
    case normal = "Dalam anggaran"
    case warning = "Melebihi anggaran"
    case alert = "Jauh melebihi anggaran"

    var badgeColor: Color {
        switch self {
        case .insufficientData: return .gray
        case .hemat: return .green
        case .normal: return .blue
        case .warning: return .orange
        case .alert: return .red
        }
    }

    var icon: String {
        switch self {
        case .insufficientData: return "tray"
        case .hemat: return "leaf.fill"
        case .normal: return "checkmark.shield.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .alert: return "flame.fill"
        }
    }
}

struct FinancialBehaviorAdvice {
    var status: FinancialStatus
    var headline: String
    var detailedAdvice: String
    var actionPlan: [String]
    var threeDayTotal: Double
    var threeDayDailyAverage: Double
    var safeDailyLimit: Double
    var topCategory: ExpenseCategory?
    var topCategoryAmount: Double
}

enum FinancialAdvisor {
    static func analyze(
        expenses: [Expense],
        dailyBudgetLimit: Double = 150_000,
        now: Date = Date()
    ) -> FinancialBehaviorAdvice {
        let calendar = Calendar.current

        // Filter expenses for the last 3 days (inclusive of today)
        guard let threeDaysAgo = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now)) else {
            return fallbackAdvice(dailyBudget: dailyBudgetLimit)
        }

        let threeDayExpenses = expenses.filter { $0.date >= threeDaysAgo && $0.date <= now && $0.amount.isFinite && $0.amount > 0 }
        guard !threeDayExpenses.isEmpty, dailyBudgetLimit.isFinite, dailyBudgetLimit > 0 else {
            return fallbackAdvice(dailyBudget: dailyBudgetLimit)
        }
        let threeDayTotal = threeDayExpenses.reduce(0) { $0 + $1.amount }
        guard threeDayTotal.isFinite else { return fallbackAdvice(dailyBudget: dailyBudgetLimit) }
        let threeDayAverage = threeDayTotal / 3.0

        // Find highest spending category in last 3 days
        var categoryTotals: [ExpenseCategory: Double] = [:]
        for exp in threeDayExpenses {
            categoryTotals[exp.category, default: 0] += exp.amount
        }
        let topCategoryEntry = categoryTotals.max(by: { $0.value < $1.value })
        let topCategory = topCategoryEntry?.key
        let topCategoryAmount = topCategoryEntry?.value ?? 0

        // Determine status based on ratio of 3-day average to safe daily budget
        let ratio = threeDayAverage / dailyBudgetLimit

        let status: FinancialStatus
        let headline: String
        if ratio > 1.4 {
            status = .alert
            headline = "Rata-rata pengeluaran jauh melebihi anggaran"
        } else if ratio > 1 {
            status = .warning
            headline = "Rata-rata pengeluaran melebihi anggaran"
        } else if ratio > 0.6 {
            status = .normal
            headline = "Rata-rata pengeluaran masih dalam anggaran"
        } else {
            status = .hemat
            headline = "Rata-rata pengeluaran di bawah anggaran"
        }
        let comparison: String
        if threeDayAverage > dailyBudgetLimit {
            comparison = "Melebihi anggaran harian sebesar \(CurrencyFormatter.format(threeDayAverage - dailyBudgetLimit))."
        } else {
            comparison = "Selisih terhadap anggaran harian sebesar \(CurrencyFormatter.format(dailyBudgetLimit - threeDayAverage))."
        }
        var detailedAdvice = "Rata-rata pengeluaran tercatat selama 3 hari adalah \(CurrencyFormatter.format(threeDayAverage))/hari, atau \(ratio.formatted(.percent.precision(.fractionLength(0)))) dari anggaran harian \(CurrencyFormatter.format(dailyBudgetLimit)). \(comparison)"
        if let topCategory {
            detailedAdvice += " Kategori terbesar adalah \(topCategory.rawValue), sebesar \(CurrencyFormatter.format(topCategoryAmount))."
        }
        detailedAdvice += " Rata-rata dihitung dari total dibagi tiga; hari tanpa catatan dihitung nol."

        var advice = FinancialBehaviorAdvice(
            status: status,
            headline: headline,
            detailedAdvice: detailedAdvice,
            actionPlan: [],
            threeDayTotal: threeDayTotal,
            threeDayDailyAverage: threeDayAverage,
            safeDailyLimit: dailyBudgetLimit,
            topCategory: topCategory,
            topCategoryAmount: topCategoryAmount
        )
        advice.actionPlan = SavingsFallback.actions(for: advice)
        return advice
    }

    private static func fallbackAdvice(dailyBudget: Double) -> FinancialBehaviorAdvice {
        FinancialBehaviorAdvice(
            status: .insufficientData,
            headline: "Belum ada ringkasan pengeluaran",
            detailedAdvice: "Catat pengeluaran dalam 3 hari terakhir dan tetapkan anggaran harian yang valid untuk melihat perbandingan.",
            actionPlan: ["Input transaksi lewat manual, suara, atau scan struk."],
            threeDayTotal: 0,
            threeDayDailyAverage: 0,
            safeDailyLimit: dailyBudget.isFinite && dailyBudget > 0 ? dailyBudget : 0,
            topCategory: nil,
            topCategoryAmount: 0
        )
    }
}
