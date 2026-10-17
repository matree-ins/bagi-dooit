//
//  FinancialAdvisor.swift
//  JustDooit
//

import SwiftUI

enum FinancialStatus: String {
    case insufficientData = "Belum cukup data"
    case hemat = "Hemat & Sehat"
    case normal = "Terkontrol"
    case warning = "Perlu Waspada"
    case alert = "Overbudget! Wajib Hemat"

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
        let ratio = threeDayAverage / max(1, dailyBudgetLimit)

        let status: FinancialStatus
        let headline: String
        let detailedAdvice: String
        var actionPlan: [String] = []

        if ratio > 1.4 {
            status = .alert
            headline = "Pengeluaran Meledak! Wajib Hemat 3 Hari ke Depan"
            if let topCat = topCategory {
                detailedAdvice = "Pengeluaran 3 hari terakhir mencapai \(CurrencyFormatter.format(threeDayTotal)) (rata-rata \(CurrencyFormatter.format(threeDayAverage))/hari), melampaui batas aman \(CurrencyFormatter.format(dailyBudgetLimit))/hari. Porsi terbesar dihabiskan untuk '\(topCat.rawValue)' (\(CurrencyFormatter.format(topCategoryAmount)))."
                actionPlan = [
                    "Freeze belanja non-esensial & jajan sampai akhir pekan.",
                    "Masak sendiri atau bawa bekal untuk menekan pos \(topCat.rawValue).",
                    "Target pengeluaran harian besok maksimal \(CurrencyFormatter.format(dailyBudgetLimit * 0.5))."
                ]
            } else {
                detailedAdvice = "Pengeluaran 3 hari terakhir mencapai \(CurrencyFormatter.format(threeDayTotal)), melebihi batas aman target kamu."
                actionPlan = ["Stop pengeluaran sekunder selama 3 hari.", "Catat setiap transaksi sekecil apa pun."]
            }
        } else if ratio > 1.0 {
            status = .warning
            headline = "Tren Pengeluaran Mulai Tinggi, Ayo Lebih Hemat!"
            detailedAdvice = "Rata-rata 3 hari terakhir adalah \(CurrencyFormatter.format(threeDayAverage))/hari, sedikit di atas target kamu (\(CurrencyFormatter.format(dailyBudgetLimit))/hari). Perlu rem sedikit agar tidak overbudget di akhir periode."
            actionPlan = [
                "Pilih alternatif transportasi atau makan yang lebih terjangkau.",
                "Tunda pembelian barang keinginan (wants) minimal 48 jam.",
                "Sisa budget aman harian: \(CurrencyFormatter.format(dailyBudgetLimit))."
            ]
        } else if ratio > 0.6 {
            status = .normal
            headline = "Keuangan Terkontrol Cukup Sehat"
            detailedAdvice = "Rata-rata pengeluaran 3 hari kamu \(CurrencyFormatter.format(threeDayAverage))/hari. Angka ini masih aman di dalam batas target harianmu."
            actionPlan = [
                "Pertahankan kebiasaan bijak berbelanja.",
                "Alokasikan sisa budget harian ke tabungan darurat.",
                "Tetap pantau transaksi rutin harian."
            ]
        } else {
            status = .hemat
            headline = "Hebat! Kamu Sangat Hemat & Disiplin 🎉"
            detailedAdvice = "Pengeluaran 3 hari terakhir hanya \(CurrencyFormatter.format(threeDayTotal)) (rata-rata \(CurrencyFormatter.format(threeDayAverage))/hari). Gaya hidup hemat ini sangat bagus untuk kesehatan finansialmu!"
            actionPlan = [
                "Sisa anggaran berpotensi dialokasikan untuk investasi.",
                "Reward diri dengan hal positif tanpa merusak cash flow.",
                "Pertahankan gaya hidup mindful spending ini!"
            ]
        }

        return FinancialBehaviorAdvice(
            status: status,
            headline: headline,
            detailedAdvice: detailedAdvice,
            actionPlan: actionPlan,
            threeDayTotal: threeDayTotal,
            threeDayDailyAverage: threeDayAverage,
            safeDailyLimit: dailyBudgetLimit,
            topCategory: topCategory,
            topCategoryAmount: topCategoryAmount
        )
    }

    private static func fallbackAdvice(dailyBudget: Double) -> FinancialBehaviorAdvice {
        FinancialBehaviorAdvice(
            status: .insufficientData,
            headline: "Mulai Catat Pengeluaranmu",
            detailedAdvice: "Belum ada cukup transaksi dalam 3 hari terakhir. Mulai catat transaksi untuk mendapatkan saran finansial cerdas!",
            actionPlan: ["Input transaksi lewat manual, suara, atau scan struk."],
            threeDayTotal: 0,
            threeDayDailyAverage: 0,
            safeDailyLimit: dailyBudget,
            topCategory: nil,
            topCategoryAmount: 0
        )
    }
}
