import Foundation

/// Exercises actual app models with isolated storage, without accessing personal data.
@main
struct RegressionChecks {
    @MainActor
    static func main() async throws {
        let now = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 12))!
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            count += 1
            print("PASS: \(message)")
        }
        func entry(_ raw: String) -> QuickEntryRequest? { URL(string: raw).flatMap(QuickEntryRequest.init(url:)) }
        check(entry("bagidooit://scan")?.method == .receiptScanner, "Widget scan route opens receipt entry")
        check(entry("bagidooit://voice")?.method == .voice, "Widget voice route opens voice entry")
        check(entry("https://scan") == nil, "Foreign URL schemes cannot open entry")
        check(entry("bagidooit://unknown") == nil, "Unknown actions are ignored")
        check(entry("bagidooit://scan/unexpected") == nil, "Unexpected URL paths are ignored")
        check(entry("bagidooit://expense") == nil, "Incomplete Siri draft is rejected")
        check(entry("bagidooit://expense?title=Kopi&amount=0") == nil, "Zero amount is rejected")
        check(entry("bagidooit://expense?title=Kopi&amount=-1") == nil, "Negative amount is rejected")
        check(entry("bagidooit://expense?title=Kopi&amount=nan") == nil, "Nonfinite amount is rejected")
        check(entry("bagidooit://expense?title=Kopi&amount=1000000001") == nil, "Excessive amount is rejected")
        check(entry("bagidooit://expense?title=%20&amount=12000") == nil, "Blank expense title is rejected")
        let draft = entry("bagidooit://expense?title=Kopi%20%26%20roti&amount=25000")
        check(draft?.title == "Kopi & roti" && draft?.amount == 25000, "Siri draft preserves encoded title and exact rupiah amount")

        let suite = "com.dicoding.bagidooit.regressions.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { fatalError("Cannot isolate storage") }
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ExpenseStore(defaults: defaults)
        check(!store.expenses.isEmpty, "Fresh install retains existing demo behavior")
        store.expenses.removeAll()
        check(ExpenseStore(defaults: defaults).expenses.isEmpty, "Deleted history stays empty after reload")
        let expense = Expense(title: "Regression", amount: 35_000, category: .food, date: now)
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

        let emptyAdvice = FinancialAdvisor.analyze(expenses: [], now: now)
        check(emptyAdvice.status == .insufficientData, "Empty history is not labelled healthy spending")
        let future = Expense(title: "Future", amount: 999_000, category: .shopping, date: now.addingTimeInterval(86_400))
        check(FinancialAdvisor.analyze(expenses: [future], now: now).totalAmount == 0, "Future expenses are excluded from AI facts")
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
        check(facts.totalAmount == expense.amount, "AI generation does not change expense totals")
        let lastGoodSuggestion = ai.suggestion
        mock.response = SavingsSuggestion(summary: "Hemat 50000 rupiah", actions: ["Satu tindakan"])
        ai.generate(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(ai.suggestion == lastGoodSuggestion && ai.notice != nil, "Malformed generated advice is rejected while same-data advice remains")
        mock.shouldFail = true
        ai.generate(for: facts)
        for _ in 0..<100 where ai.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(ai.suggestion == lastGoodSuggestion && ai.notice != nil && !ai.isGenerating, "Generation failure retains valid advice for unchanged data")
        mock.shouldFail = false
        mock.delay = 50_000_000
        ai.generate(for: facts)
        await Task.yield()
        ai.invalidate()
        try await Task.sleep(nanoseconds: 60_000_000)
        check(ai.suggestion == nil && ai.notice == nil && !ai.isGenerating, "Cancelled generation cannot publish stale advice")
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
        let monthRecords = (0..<15).map { offset in
            Expense(title: "Day", amount: 100_000, category: .shopping, date: Calendar.current.date(byAdding: .day, value: -offset, to: now)!)
        }
        let budgetFacts = budgets.map { FinancialAdvisor.analyze(expenses: monthRecords, dailyBudgetLimit: $0, now: now) }
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
            FinancialAdvisor.analyze(expenses: (0..<15).map { offset in
                Expense(title: "Boundary", amount: average, category: .food, date: Calendar.current.date(byAdding: .day, value: -offset, to: now)!)
            }, dailyBudgetLimit: 100_000, now: now).status
        }
        check(statusAt(60_000) == .hemat && statusAt(60_001) == .normal, "Sixty percent boundary is classified correctly")
        check(statusAt(100_000) == .normal && statusAt(100_001) == .warning, "Any amount above budget is labelled exceeding budget")
        check(statusAt(140_000) == .warning && statusAt(140_001) == .alert, "Substantial overspending starts strictly above forty percent excess")
        check(FinancialAdvisor.analyze(expenses: [sample], dailyBudgetLimit: 0, now: now).status == .insufficientData, "Invalid budget does not imply healthy finances")
        check(FinancialAdvisor.analyze(expenses: [sample], dailyBudgetLimit: .nan, now: now).safeDailyLimit == 0, "Invalid budget never leaks NaN into presentation")
        check(!FinancialStatus.hemat.rawValue.contains("Sehat") && FinancialStatus.warning.rawValue == "Melebihi anggaran", "Labels describe the budget comparison without financial health claims")

        let sparse = FinancialAdvisor.analyze(expenses: [expense], dailyBudgetLimit: 500_000, now: now)
        check(sparse.recordedDayCount == 1 && sparse.periodDayCount == 15 && sparse.dailyAverage == expense.amount / 15, "Daily average starts at the beginning of the month even if recording starts later")
        let sparseOver = FinancialAdvisor.analyze(expenses: [Expense(title: "Known excess", amount: 9_000_000, category: .food, date: now)], dailyBudgetLimit: 50_000, now: now)
        check(sparseOver.status == .alert, "Known overspending is still flagged with sparse data")
        let old = Expense(title: "Outside window", amount: 999_999, category: .health, date: Calendar.current.date(byAdding: .day, value: -4, to: now)!)
        let windowFacts = FinancialAdvisor.analyze(expenses: monthRecords + [old, future], now: now)
        check(windowFacts.categoryTotals == [.shopping: 1_500_000, .health: 999_999] && windowFacts.categoryTotals.values.reduce(0, +) == windowFacts.totalAmount, "Categories and analysis use the same month-to-date period")
        check(windowFacts.recordedDayCount == 15 && windowFacts.periodDayCount == 15, "Month-to-date period counts calendar days from the first")
        let unchangedFacts = FinancialAdvisor.analyze(expenses: monthRecords + [old], now: now)
        check(SavingsAdviceKey(windowFacts, now: now) == SavingsAdviceKey(unchangedFacts, now: now), "Future transactions do not change the all-history model context")
        let cachingProvider = MockSavingsProvider()
        let cachingAI = SavingsAIService(provider: cachingProvider, debounceNanoseconds: 0)
        cachingAI.refresh(for: unchangedFacts, now: now)
        for _ in 0..<100 where cachingAI.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        cachingAI.refresh(for: windowFacts, now: now)
        check(cachingProvider.calls == 1 && !cachingAI.isGenerating, "Future-only history changes reuse generated advice")
        let cached = cachingAI.suggestion
        cachingProvider.delay = 30_000_000
        cachingAI.refresh(for: windowFacts, force: true, now: now)
        check(cachingAI.suggestion == cached && cachingAI.isGenerating, "Same-data manual refresh never blanks valid advice")
        cachingAI.pause()
        check(cachingAI.suggestion == cached && !cachingAI.isGenerating, "Backgrounding preserves valid same-data advice during refresh")
        var newContext = windowFacts
        newContext.safeDailyLimit += 25_000
        cachingAI.refresh(for: newContext, now: now)
        check(cachingAI.suggestion == nil, "Advice for an old budget is not shown with a new budget")
        cachingAI.invalidate()
        let repeatedProvider = MockSavingsProvider()
        repeatedProvider.failure = URLError(.notConnectedToInternet)
        let repeatedAI = SavingsAIService(provider: repeatedProvider, debounceNanoseconds: 0)
        repeatedAI.refresh(for: unchangedFacts, now: now)
        for _ in 0..<100 where repeatedAI.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(repeatedAI.errorNotice != nil, "First automatic failure publishes one toast")
        repeatedAI.dismissError()
        repeatedAI.refresh(for: unchangedFacts, now: now.addingTimeInterval(61))
        for _ in 0..<100 where repeatedAI.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(repeatedAI.errorNotice == nil && repeatedProvider.calls == 2, "Repeated automatic failure for the same data does not repeat its toast")
        repeatedAI.refresh(for: unchangedFacts, force: true, now: now.addingTimeInterval(62))
        for _ in 0..<100 where repeatedAI.isGenerating { try await Task.sleep(nanoseconds: 1_000_000) }
        check(repeatedAI.errorNotice != nil, "User-requested retry can report a fresh failure")
        store.refreshAnalysisDay(now: now.addingTimeInterval(86_400))
        check(store.analysisDay == Calendar.current.startOfDay(for: now.addingTimeInterval(86_400)), "Foreground day refresh invalidates rendered period data")

        let rolledWindow = FinancialAdvisor.analyze(expenses: monthRecords, now: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
        check(rolledWindow.totalAmount == 1_500_000 && rolledWindow.categoryTotals == [.shopping: 1_500_000] && rolledWindow.recordedDayCount == 15 && rolledWindow.periodDayCount == 16 && rolledWindow.dailyAverage == 93_750, "Day rollover retains old history and extends the calendar-average denominator")

        let ancient = Expense(title: "Older history", amount: 310_000, category: .transport, date: Calendar.current.date(byAdding: .day, value: -30, to: now)!)
        let longHistory = FinancialAdvisor.analyze(expenses: [ancient], now: now)
        check(longHistory.totalAmount == 0 && longHistory.periodDayCount == 15 && longHistory.dailyAverage == 0, "Previous-month transactions do not contribute to current-month totals")
        check(longHistory.periodBudget == 15 * longHistory.safeDailyLimit, "Budget-to-date uses only elapsed days of this month")
        let sameDay = FinancialAdvisor.analyze(expenses: [expense, expense], now: now)
        check(sameDay.periodDayCount == 15 && sameDay.dailyAverage == expense.amount * 2 / 15, "Multiple transactions do not change the elapsed-day denominator")
        check(SavingsAdviceKey(windowFacts, now: now) != SavingsAdviceKey(FinancialAdvisor.analyze(expenses: monthRecords, now: now), now: now), "Adding an older expense refreshes the AI context")

        let monthStart = Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 1, hour: 12))!
        let firstDayExpense = Expense(title: "First", amount: 12_000, category: .food, date: monthStart)
        let firstMonthDay = FinancialAdvisor.analyze(expenses: monthRecords + [firstDayExpense], now: monthStart)
        check(firstMonthDay.totalAmount == 12_000 && firstMonthDay.periodDayCount == 1 && firstMonthDay.dailyAverage == 12_000, "New month resets aggregation and has a safe one-day denominator")
        let emptyNewMonth = FinancialAdvisor.analyze(expenses: monthRecords, now: monthStart)
        check(emptyNewMonth.totalAmount == 0 && emptyNewMonth.status == .insufficientData && emptyNewMonth.categoryTotals.isEmpty, "Previous month does not leak into an empty new month")
        let leapDay = Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 12))!
        let leapFacts = FinancialAdvisor.analyze(expenses: [Expense(title: "Leap", amount: 290_000, category: .food, date: monthStart)], now: leapDay)
        check(leapFacts.periodDayCount == 29 && leapFacts.dailyAverage == 10_000, "Leap-year February uses calendar days correctly")
        let priorMonthExpense = Expense(title: "Prior month", amount: 9_999_999, category: .other, date: Calendar.current.date(from: DateComponents(year: 2023, month: 12, day: 31, hour: 12))!)
        let onlyThisMonth = FinancialAdvisor.analyze(expenses: monthRecords, now: now)
        let withPriorMonth = FinancialAdvisor.analyze(expenses: monthRecords + [priorMonthExpense], now: now)
        check(SavingsAdviceKey(onlyThisMonth, now: now) == SavingsAdviceKey(withPriorMonth, now: now), "Prior-month edits do not invalidate current-month AI cache")

        let savedSplit = SplitBillSession(title: "Completion regression", participants: [a, b], items: [SplitItem(name: "Meal", price: 40_000, assignedParticipantIds: [a.id, b.id])])
        store.addSplitSession(savedSplit)
        store.addSplitSession(savedSplit)
        check(store.splitSessions.filter { $0.id == savedSplit.id }.count == 1, "Repeated completion does not duplicate the split bill")
        check(ExpenseStore(defaults: defaults).splitSessions.contains { $0.id == savedSplit.id }, "Completed split bill survives store reload")
        let unavailable = MockSavingsProvider()
        unavailable.availabilityIssue = "Saran AI tidak tersedia pada perangkat ini."
        unavailable.availabilityCanRetry = false
        let unavailableService = SavingsAIService(provider: unavailable, debounceNanoseconds: 0)
        unavailableService.refresh(for: facts)
        check(unavailableService.notice == unavailable.availabilityIssue, "Unavailable AI notification has no extra sentence")
        print("\(count) regression checks passed")
    }
}
