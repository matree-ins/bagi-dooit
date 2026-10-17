import Foundation

struct SavingsAdviceKey: Equatable {
    let day: Date
    let total: Double
    let average: Double
    let budget: Double
    let category: ExpenseCategory?
    let categoryAmount: Double

    init(_ advice: FinancialBehaviorAdvice, now: Date) {
        day = Calendar.current.startOfDay(for: now)
        total = advice.threeDayTotal
        average = advice.threeDayDailyAverage
        budget = advice.safeDailyLimit
        category = advice.topCategory
        categoryAmount = advice.topCategoryAmount
    }
}
