import Foundation

/// Exercises actual app models with isolated storage, without accessing personal data.
@main
struct RegressionChecks {
    @MainActor
    static func main() throws {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            count += 1
            print("PASS: \(message)")
        }
        let suite = "com.dicoding.bagidooit.regressions.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { fatalError("Cannot isolate storage") }
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ExpenseStore(defaults: defaults)
        check(!store.expenses.isEmpty, "Fresh install retains existing demo behavior")
        store.expenses.removeAll()
        check(ExpenseStore(defaults: defaults).expenses.isEmpty, "Deleted history stays empty after reload")
        let expense = Expense(title: "Regression", amount: 35_000, category: .food)
        store.addExpense(expense)
        check(ExpenseStore(defaults: defaults).expenses == [expense], "Expenses survive reload")
        store.dailyBudgetLimit = 75_000
        check(ExpenseStore(defaults: defaults).dailyBudgetLimit == 75_000, "Budget survives reload")
        let a = SplitParticipant(name: "A", phoneNumber: "")
        let b = SplitParticipant(name: "B", phoneNumber: "")
        var bill = SplitBillSession(title: "Regression", participants: [a, b], items: [
            SplitItem(name: "Assigned", price: 100_000, assignedParticipantIds: [a.id, b.id]),
            SplitItem(name: "Unassigned", price: 100_000)
        ])
        check(!bill.canShare && bill.sharingIssue != nil, "Unassigned items block sharing")
        bill.items[1].assignedParticipantIds = [a.id, b.id]
        check(bill.canShare, "Complete allocations can be shared")
        let total = bill.participants.reduce(0) { $0 + bill.participantTotal(for: $1.id) }
        check(abs(total - bill.total) < 0.01, "Shares equal the bill including fees")
        bill.items[1].assignedParticipantIds = [UUID()]
        check(!bill.canShare, "Unknown participants block sharing")
        bill.items[1].assignedParticipantIds = [a.id]
        bill.items[0].price = .nan
        check(!bill.canShare, "Nonfinite prices block sharing")
        bill.items.removeAll()
        check(!bill.canShare, "Empty bills block sharing")
        let item = ScannedReceiptItem(name: "Kopi", price: 35_000)
        let first = ReceiptScanResult(merchantName: "Toko A", items: [item], totalAmount: 35_000, rawLines: ["A"])
        let second = ReceiptScanResult(merchantName: "Toko B", items: [item], totalAmount: 35_000, rawLines: ["B"])
        check(first.totalAmount == second.totalAmount && first != second, "Equal totals do not hide a different receipt")
        let decoded = try JSONDecoder().decode([Expense].self, from: JSONEncoder().encode([Expense]()))
        check(decoded.isEmpty, "An empty stored list is valid data")
        print("\(count) regression checks passed")
    }
}
