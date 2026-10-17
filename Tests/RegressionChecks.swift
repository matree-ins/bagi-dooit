import Foundation

/// Exercises actual app models with isolated storage, without accessing personal data.
@main
struct RegressionChecks {
    @MainActor
    static func main() async throws {
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

        let now = Date()
        let emptyAdvice = FinancialAdvisor.analyze(expenses: [], now: now)
        check(emptyAdvice.status == .insufficientData, "Empty history is not labelled healthy spending")
        let future = Expense(title: "Future", amount: 999_000, category: .shopping, date: now.addingTimeInterval(86_400))
        check(FinancialAdvisor.analyze(expenses: [future], now: now).threeDayTotal == 0, "Future expenses are excluded from AI facts")
        let facts = FinancialAdvisor.analyze(expenses: [expense], now: now)
        let mock = MockSavingsProvider()
        let ai = SavingsAIService(provider: mock, debounceNanoseconds: 0)
        ai.generate(for: emptyAdvice)
        check(ai.notice == nil && mock.calls == 0 && !ai.isGenerating, "Empty data never triggers AI")
        mock.availabilityIssue = "Model unavailable"
        ai.generate(for: facts)
        check(ai.notice?.contains("Model unavailable") == true && mock.calls == 0, "Unavailable AI keeps fallback")
        mock.availabilityIssue = nil
        ai.generate(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(ai.suggestion == mock.response && ai.notice == nil, "Valid generated advice is displayed")
        check(facts.threeDayTotal == expense.amount, "AI generation does not change expense totals")
        mock.response = SavingsSuggestion(summary: "Hemat 50000 rupiah", actions: ["Satu tindakan"])
        ai.generate(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(ai.suggestion == nil && ai.notice != nil, "Malformed or numerical generated advice is rejected")
        mock.shouldFail = true
        ai.generate(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(ai.suggestion == nil && ai.notice != nil && !ai.isGenerating, "Generation failure restores fallback")
        mock.shouldFail = false
        mock.delay = 50_000_000
        ai.generate(for: facts)
        await Task.yield()
        ai.invalidate()
        try await Task.sleep(nanoseconds: 60_000_000)
        check(ai.suggestion == nil && ai.notice == nil && !ai.isGenerating, "Cancelled generation cannot publish stale advice")
        store.savingsAI.generate(for: emptyAdvice)
        store.dailyBudgetLimit += 1
        check(store.savingsAI.notice == nil, "Budget changes invalidate cached advice")
        store.savingsAI.generate(for: emptyAdvice)
        store.addExpense(expense)
        check(store.savingsAI.notice == nil, "Expense changes invalidate cached advice")

        check(!SavingsSuggestion(summary: "Angka 100", actions: ["Periksa kebutuhan.", "Rencanakan belanja."]).isValid, "Numerical AI claims are rejected even with valid action count")
        check(!SavingsSuggestion(summary: "Ringkasan", actions: ["Sama", "Sama"]).isValid, "Duplicate AI actions are rejected")
        check(!SavingsSuggestion(summary: " ", actions: ["Periksa kebutuhan.", "Rencanakan belanja."]).isValid, "Empty AI summaries are rejected")

        mock.response = SavingsSuggestion(summary: "Belanja mendominasi pengeluaran tercatat.", actions: ["Buat daftar kebutuhan.", "Tinjau pembelian yang belum diperlukan."])
        mock.delay = 0
        mock.failure = nil
        ai.invalidate()
        let before = mock.calls
        ai.refresh(for: facts)
        ai.refresh(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        ai.refresh(for: facts)
        check(mock.calls == before + 1 && ai.suggestion != nil, "Automatic refresh deduplicates in-flight and cached requests")
        mock.failure = URLError(.notConnectedToInternet)
        ai.generate(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(ai.errorNotice?.message.contains("Koneksi terputus") == true && ai.errorNotice?.canRetry == true, "Connectivity failure produces a friendly retryable toast event")
        let failedCalls = mock.calls
        let errorID = ai.errorNotice?.id
        ai.refresh(for: facts)
        check(mock.calls == failedCalls && ai.errorNotice?.id == errorID, "Repeated renders do not duplicate failed requests or toast events")
        ai.dismissError()
        ai.refresh(for: facts)
        check(ai.errorNotice == nil && mock.calls == failedCalls, "Dismissed errors stay dismissed during cooldown")
        mock.failure = nil
        ai.generate(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(ai.suggestion != nil && ai.errorNotice == nil, "Explicit retry recovers after connection failure")
        mock.failure = URLError(.timedOut)
        ai.generate(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(ai.notice?.contains("terlalu lama") == true, "Provider timeout has a readable message")
        mock.failure = CancellationError()
        ai.generate(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(ai.errorNotice == nil && !ai.isGenerating, "Cancellation does not show an error toast")
        mock.failure = nil
        mock.delay = 100_000_000
        let timeoutAI = SavingsAIService(provider: mock, timeoutNanoseconds: 5_000_000, debounceNanoseconds: 0)
        timeoutAI.refresh(for: facts)
        try await Task.sleep(nanoseconds: 20_000_000)
        check(!timeoutAI.isGenerating && timeoutAI.suggestion == nil && timeoutAI.notice?.contains("terlalu lama") == true, "Watchdog stops hung generation and ignores its late result")
        let debounceAI = SavingsAIService(provider: mock, debounceNanoseconds: 40_000_000)
        let beforeDebounce = mock.calls
        debounceAI.refresh(for: facts)
        debounceAI.invalidate()
        try await Task.sleep(nanoseconds: 50_000_000)
        check(mock.calls == beforeDebounce && debounceAI.notice == nil, "Debounced request cancels silently before calling model")
        mock.delay = 0
        mock.availabilityIssue = "Aktifkan Apple Intelligence."
        mock.availabilityCanRetry = false
        ai.generate(for: facts)
        check(ai.errorNotice?.canRetry == false, "Unsupported or disabled model does not offer a pointless retry")
        mock.availabilityIssue = nil
        ai.refresh(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(ai.suggestion != nil, "Model becoming ready bypasses failed-attempt cooldown")
        ai.pause()
        ai.refresh(for: facts)
        check(ai.suggestion != nil && !ai.isGenerating, "Completed advice is reused after foreground return")
        let fallback = SavingsFallback.actions(for: facts)
        check(!fallback.isEmpty && fallback != SavingsFallback.actions(for: emptyAdvice), "Fallback tips depend on actual data and handle empty history")

        mock.failure = URLError(.cancelled)
        ai.generate(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(ai.errorNotice == nil && !ai.isGenerating, "System URL cancellation stays silent")
        mock.failure = nil
        mock.delay = 40_000_000
        ai.invalidate()
        let startCalls = mock.calls
        ai.refresh(for: facts)
        for _ in 0..<100 where mock.calls == startCalls { try await Task.sleep(nanoseconds: 1_000_000) }
        mock.response = SavingsSuggestion(summary: "Ringkasan terbaru.", actions: ["Periksa kebutuhan terbaru.", "Tinjau anggaran terbaru."])
        var changedFacts = facts
        changedFacts.safeDailyLimit += 25_000
        ai.refresh(for: changedFacts)
        try await Task.sleep(nanoseconds: 60_000_000)
        check(ai.suggestion == mock.response, "Older generation cannot overwrite changed-budget advice")
        mock.delay = 0
        ai.invalidate()
        ai.refresh(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        let beforeNextDay = mock.calls
        ai.refresh(for: facts, now: now.addingTimeInterval(86_400))
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(mock.calls == beforeNextDay + 1, "A new calendar day refreshes cached advice")

        let english = MockSavingsProvider()
        english.usesEnglish = true
        english.response = SavingsSuggestion(summary: "Shopping is the largest recorded category.", actions: ["Review purchases before shopping.", "Plan essential spending."])
        let directAI = SavingsAIService(provider: english, debounceNanoseconds: 0)
        directAI.refresh(for: facts)
        for _ in 0..<100 where directAI.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(directAI.suggestion == english.response && directAI.notice == nil, "English AI output is displayed directly without translation")

        let sample = Expense(title: "Budget check", amount: 300_000, category: .shopping, date: now)
        let budgets = [50_000.0, 90_000.0, 125_000.0, 200_000.0]
        let budgetFacts = budgets.map { FinancialAdvisor.analyze(expenses: [sample], dailyBudgetLimit: $0, now: now) }
        check(budgetFacts.map(\.status) == [.alert, .warning, .normal, .hemat], "The same expenses react to four daily budget levels")
        let budgetActions = budgetFacts.map { SavingsFallback.actions(for: $0).last ?? "" }
        check(Set(budgetActions).count == 4, "Fallback budget guidance differs across all four budget levels")
        let budgetProvider = MockSavingsProvider()
        let budgetService = SavingsAIService(provider: budgetProvider, debounceNanoseconds: 0)
        for budgetFact in budgetFacts {
            budgetService.refresh(for: budgetFact)
            for _ in 0..<100 where budgetService.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        }
        check(budgetProvider.receivedBudgets == budgets, "Every budget change reaches the AI provider with its new value")

        func statusAt(_ average: Double) -> FinancialStatus {
            FinancialAdvisor.analyze(expenses: [Expense(title: "Boundary", amount: average * 3, category: .food, date: now)], dailyBudgetLimit: 100_000, now: now).status
        }
        check(statusAt(60_000) == .hemat && statusAt(60_001) == .normal, "Sixty percent boundary is classified correctly")
        check(statusAt(100_000) == .normal && statusAt(100_001) == .warning, "Any amount above budget is labelled exceeding budget")
        check(statusAt(140_000) == .warning && statusAt(140_001) == .alert, "Substantial overspending starts strictly above forty percent excess")
        check(FinancialAdvisor.analyze(expenses: [sample], dailyBudgetLimit: 0, now: now).status == .insufficientData, "Invalid budget does not imply healthy finances")
        check(FinancialAdvisor.analyze(expenses: [sample], dailyBudgetLimit: .nan, now: now).safeDailyLimit == 0, "Invalid budget never leaks NaN into presentation")
        check(!FinancialStatus.hemat.rawValue.contains("Sehat") && FinancialStatus.warning.rawValue == "Melebihi anggaran", "Labels describe the budget comparison without financial health claims")
        print("\(count) regression checks passed")
    }
}
