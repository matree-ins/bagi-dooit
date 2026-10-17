import Foundation
import FoundationModels

@MainActor
struct FoundationSavingsProvider: SavingsSuggestionProviding {
    var availabilityIssue: String? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(Locale(identifier: "id_ID")) || model.supportsLocale(Locale(identifier: "en_US"))
                ? nil : "Bahasa untuk saran AI belum didukung pada perangkat ini."
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return "Saran AI tidak tersedia pada perangkat ini."
            case .appleIntelligenceNotEnabled: return "Aktifkan Apple Intelligence untuk menggunakan saran AI."
            case .modelNotReady: return "AI di perangkat belum siap. Sambungkan internet agar unduhan model bisa selesai, lalu coba lagi."
            @unknown default: return "Saran AI sedang tidak tersedia."
            }
        }
    }

    var availabilityCanRetry: Bool {
        switch SystemLanguageModel.default.availability {
        case .available: return false
        case .unavailable(.modelNotReady): return true
        default: return false
        }
    }

    var usesEnglish: Bool {
        !SystemLanguageModel.default.supportsLocale(Locale(identifier: "id_ID"))
    }

    func generate(for advice: FinancialBehaviorAdvice) async throws -> SavingsSuggestion {
        let language = usesEnglish ? "English" : "Indonesian"
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: """
            Help a Bagi Dooit user understand everyday spending habits. Respond only in \(language).
            Keep the response short, friendly and based only on the supplied facts.
            The app already calculated all figures and the budget status. Do not calculate, change or repeat them.
            Do not write numbers, amounts, percentages, numerical targets, predictions or promised savings.
            Records may be incomplete. Do not infer financial health, income, debts or personal needs.
            Only describe the largest recorded category and the supplied calendar-average budget status.
            There is no evidence of recurrence or a day-by-day trend. Never claim spending was consistent, recurring, increasing, or over budget on individual days.
            Never recommend investments or loans. Suggest relevant everyday spending habits.
            For health or bills, suggest reviewing charges and planning essential payments, not cutting essential needs.
            """)
        let status: String
        switch advice.status {
        case .insufficientData: status = "insufficient records or invalid daily budget; no budget conclusion is justified"
        case .hemat: status = "recorded average within sixty percent of daily budget"
        case .normal: status = "recorded average within daily budget"
        case .warning: status = "recorded average above daily budget"
        case .alert: status = "recorded average substantially above daily budget"
        }
        let budgetGuidance: String
        switch advice.status {
        case .alert:
            budgetGuidance = "Recorded spending substantially exceeds the budget. Prioritize essentials and suggest deferring nonessential purchases."
        case .warning:
            budgetGuidance = "Recorded spending is above the budget. Suggest a small practical adjustment in the largest category without cutting essential needs."
        case .normal:
            budgetGuidance = "Recorded spending fits the budget. Suggest maintaining the current limit and checking before adding discretionary purchases. Do not imply overspending."
        case .hemat:
            budgetGuidance = "Recorded spending is well below the budget. Suggest maintaining habits and keeping the unused allowance, not spending it or making drastic cuts."
        case .insufficientData:
            budgetGuidance = "Ask the user to complete records before judging the budget."
        }
        let category = categoryName(advice.topCategory)
        let distribution = advice.categoryTotals.sorted {
            $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value
        }.map { "\(categoryName($0.key)): \($0.value)" }.joined(separator: "; ")
        let response = try await session.respond(to: """
            Trusted app summary for the current calendar month, from its first day through today:
            Number of calendar days with records: \(advice.recordedDayCount) out of \(advice.periodDayCount).
            The recorded total is divided by elapsed calendar days since the first day of this month, including days without records. Missing records are not proof of zero spending.
            Records may be incomplete. Status: \(status).
            Recorded total: \(advice.totalAmount).
            Calendar daily average: \(advice.dailyAverage).
            Daily budget: \(advice.safeDailyLimit).
            Unused daily allowance based on the recorded calendar average: \(max(0, advice.safeDailyLimit - advice.dailyAverage)).
            Budget-specific guidance: \(budgetGuidance)
            Tailor the actions to this budget situation as well as the largest category. Do not use the same restrictive advice for an under-budget situation as for an over-budget situation.
            Recorded category totals for the same period: \(distribution).
            Largest recorded category: \(category), amount: \(advice.topCategoryAmount).
            Describe the spending pattern and suggest practical habits without repeating any figures.
            """, generating: GeneratedSavingsSuggestion.self,
            options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 450))
        return SavingsSuggestion(summary: response.content.summary, actions: response.content.actions)
    }
    private func categoryName(_ category: ExpenseCategory?) -> String {
        switch category {
        case .food: return "food and drinks"
        case .transport: return "transport"
        case .shopping: return "shopping"
        case .bills: return "bills and utilities"
        case .entertainment: return "entertainment"
        case .health: return "health"
        case .other: return "other"
        case nil: return "unknown"
        }
    }
}
