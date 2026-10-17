import Foundation

struct SavingsAdviceKey: Equatable {
    let day: Date
    let total: Double
    let average: Double
    let budget: Double
    let category: ExpenseCategory?
    let categoryAmount: Double
    let categoryTotals: [ExpenseCategory: Double]
    let periodDayCount: Int
    let periodStart: Date?
    let recordedDayCount: Int
    let status: FinancialStatus

    init(_ advice: FinancialBehaviorAdvice, now: Date) {
        day = Calendar.current.startOfDay(for: now)
        total = advice.totalAmount
        average = advice.dailyAverage
        budget = advice.safeDailyLimit
        category = advice.topCategory
        categoryAmount = advice.topCategoryAmount
        categoryTotals = advice.categoryTotals
        recordedDayCount = advice.recordedDayCount
        periodDayCount = advice.periodDayCount
        periodStart = advice.periodStart
        status = advice.status
    }
}
