import Foundation

@MainActor
enum SiriRecordingService {
    /// Confirmation is injected so cancellation and failures can be tested without invoking Siri.
    static func recordSplitBill(_ draft: SiriSplitBillDraft, store: ExpenseStore,
                                confirmation: () async throws -> Void) async throws {
        guard draft.session.canShare else { throw SiriEntryError.invalidBill }
        try await confirmation()
        try Task.checkCancellation()
        store.addSplitSession(draft.session)
    }

    static func recordExpense(_ expense: Expense, store: ExpenseStore,
                              confirmation: () async throws -> Void) async throws {
        _ = try SiriEntryValidator.amount(expense.amount)
        _ = try SiriEntryValidator.title(expense.title)
        try await confirmation()
        try Task.checkCancellation()
        guard !store.expenses.contains(where: { $0.id == expense.id }) else { return }
        store.addExpense(expense)
    }
}
