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
    var totalAmount: Double
    var dailyAverage: Double
    var safeDailyLimit: Double
    var topCategory: ExpenseCategory?
    var topCategoryAmount: Double
    var categoryTotals: [ExpenseCategory: Double] = [:]
    var recordedDayCount: Int = 0
    var periodDayCount: Int = 0
    var periodStart: Date? = nil

    var periodBudget: Double { safeDailyLimit * Double(periodDayCount) }
}

enum FinancialAdvisor {
    static func analyze(
        expenses: [Expense],
        dailyBudgetLimit: Double = 150_000,
        now: Date = Date()
    ) -> FinancialBehaviorAdvice {
        let calendar = Calendar.current

        guard let periodStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return fallbackAdvice(dailyBudget: dailyBudgetLimit, now: now)
        }
        let validExpenses = expenses.filter { $0.date >= periodStart && $0.date <= now && $0.amount.isFinite && $0.amount > 0 }
        guard !validExpenses.isEmpty, dailyBudgetLimit.isFinite, dailyBudgetLimit > 0 else {
            return fallbackAdvice(dailyBudget: dailyBudgetLimit, now: now)
        }
        let totalAmount = validExpenses.reduce(0) { $0 + $1.amount }
        guard totalAmount.isFinite else { return fallbackAdvice(dailyBudget: dailyBudgetLimit, now: now) }
        let periodDayCount = max(1, (calendar.dateComponents([.day], from: periodStart, to: calendar.startOfDay(for: now)).day ?? 0) + 1)
        let dailyAverage = totalAmount / Double(periodDayCount)

        // Summarize every valid expense in the current month.
        var categoryTotals: [ExpenseCategory: Double] = [:]
        for exp in validExpenses {
            categoryTotals[exp.category, default: 0] += exp.amount
        }
        let recordedDayCount = Set(validExpenses.map { calendar.startOfDay(for: $0.date) }).count
        let topCategoryEntry = categoryTotals.sorted {
            $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value
        }.first
        let topCategory = topCategoryEntry?.key
        let topCategoryAmount = topCategoryEntry?.value ?? 0

        // Compare the month-to-date calendar average with the daily budget.
        let ratio = dailyAverage / dailyBudgetLimit

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
        if dailyAverage > dailyBudgetLimit {
            comparison = "Melebihi anggaran harian sebesar \(CurrencyFormatter.format(dailyAverage - dailyBudgetLimit))."
        } else {
            comparison = "Selisih terhadap anggaran harian sebesar \(CurrencyFormatter.format(dailyBudgetLimit - dailyAverage))."
        }
        let detailedAdvice = "Rata-rata tercatat \(CurrencyFormatter.format(dailyAverage))/hari, sekitar \(ratio.formatted(.percent.precision(.fractionLength(0...2)))) dari anggaran. \(comparison)"

        var advice = FinancialBehaviorAdvice(
            status: status,
            headline: headline,
            detailedAdvice: detailedAdvice,
            actionPlan: [],
            totalAmount: totalAmount,
            dailyAverage: dailyAverage,
            safeDailyLimit: dailyBudgetLimit,
            topCategory: topCategory,
            topCategoryAmount: topCategoryAmount,
            categoryTotals: categoryTotals,
            recordedDayCount: recordedDayCount,
            periodDayCount: periodDayCount,
            periodStart: periodStart
        )
        advice.actionPlan = SavingsFallback.actions(for: advice)
        return advice
    }

    private static func fallbackAdvice(dailyBudget: Double, now: Date) -> FinancialBehaviorAdvice {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        let elapsed = max(1, (calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day ?? 0) + 1)
        return FinancialBehaviorAdvice(
            status: .insufficientData,
            headline: "Belum ada ringkasan pengeluaran",
            detailedAdvice: "Catat pengeluaran dan tetapkan anggaran harian yang valid untuk melihat ringkasan bulan ini.",
            actionPlan: ["Input transaksi lewat manual, suara, atau scan struk."],
            totalAmount: 0,
            dailyAverage: 0,
            safeDailyLimit: dailyBudget.isFinite && dailyBudget > 0 ? dailyBudget : 0,
            topCategory: nil,
            topCategoryAmount: 0,
            periodDayCount: elapsed,
            periodStart: start
        )
    }
}
