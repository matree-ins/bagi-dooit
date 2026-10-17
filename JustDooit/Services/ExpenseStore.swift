//
//  ExpenseStore.swift
//  JustDooit
//

import Foundation
import Observation

@Observable
@MainActor
final class ExpenseStore {
    /// Siri and all app windows share one observable store in the app process.
    static let shared = ExpenseStore()

    var userName: String = "Teman Dooit" {
        didSet {
            defaults.set(userName, forKey: "UserNameKey")
        }
    }

    var expenses: [Expense] = [] {
        didSet {
            saveToStorage()
        }
    }

    var dailyBudgetLimit: Double = 150_000 {
        didSet {
            defaults.set(dailyBudgetLimit, forKey: "DailyBudgetLimitKey")
        }
    }

    let savingsAI = SavingsAIService(provider: FoundationSavingsProvider())

    private(set) var analysisDay = Calendar.current.startOfDay(for: Date())

    func refreshAnalysisDay(now: Date = Date()) {
        let day = Calendar.current.startOfDay(for: now)
        if day != analysisDay { analysisDay = day }
    }

    var splitSessions: [SplitBillSession] = [] {
        didSet {
            saveSplitSessionsToStorage()
        }
    }

    @ObservationIgnored private let storageKey = "JustDooit_Expenses_v1"
    @ObservationIgnored private let splitSessionsKey = "JustDooit_SplitSessions_v1"
    @ObservationIgnored private let dummyCleanedKey = "JustDooit_HasCleanedDummyData_v4"
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let savedName = defaults.string(forKey: "UserNameKey"), !savedName.isEmpty, savedName != "Rina" {
            self.userName = savedName
        } else {
            self.userName = "Teman Dooit"
        }
        if let savedBudget = defaults.value(forKey: "DailyBudgetLimitKey") as? Double, savedBudget > 0 {
            self.dailyBudgetLimit = savedBudget
        }
        loadFromStorage()
        loadSplitSessionsFromStorage()
        cleanDummyDataIfNeeded()
        syncAllSplitSessions()
    }

    var totalExpensesAllTime: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var totalExpensesToday: Double {
        let calendar = Calendar.current
        return expenses.filter { calendar.isDateInToday($0.date) }.reduce(0) { $0 + $1.amount }
    }

    var currentAdvice: FinancialBehaviorAdvice {
        FinancialAdvisor.analyze(expenses: expenses, dailyBudgetLimit: dailyBudgetLimit)
    }

    func addExpense(_ expense: Expense) {
        expenses.insert(expense, at: 0)
    }

    func deleteExpense(at offsets: IndexSet) {
        let toDelete = offsets.map { expenses[$0] }
        for exp in toDelete {
            if let sessionId = exp.splitSessionId {
                splitSessions.removeAll { $0.id == sessionId }
            }
        }
        for index in offsets.sorted(by: >) {
            expenses.remove(at: index)
        }
    }

    func deleteExpense(id: UUID) {
        if let exp = expenses.first(where: { $0.id == id }), let sessionId = exp.splitSessionId {
            splitSessions.removeAll { $0.id == sessionId }
        }
        expenses.removeAll { $0.id == id }
    }

    func addSplitSession(_ session: SplitBillSession) {
        if let idx = splitSessions.firstIndex(where: { $0.id == session.id }) {
            splitSessions[idx] = session
        } else {
            splitSessions.insert(session, at: 0)
        }
        syncExpenseForSplitSession(session)
    }

    func updateSplitSession(_ session: SplitBillSession) {
        if let idx = splitSessions.firstIndex(where: { $0.id == session.id }) {
            splitSessions[idx] = session
        }
        syncExpenseForSplitSession(session)
    }

    func deleteSplitSession(id: UUID) {
        splitSessions.removeAll { $0.id == id }
        expenses.removeAll { $0.splitSessionId == id }
    }

    func syncExpenseForSplitSession(_ session: SplitBillSession) {
        // Find current user's participant ("Saya" or userName)
        let myParticipant = session.participants.first(where: {
            $0.name == "Saya" || $0.name.localizedCaseInsensitiveCompare(userName) == .orderedSame
        }) ?? session.participants.first

        let myPortion: Double
        if let p = myParticipant {
            let total = session.participantTotal(for: p.id)
            if total > 0 {
                myPortion = total
            } else if session.participants.count > 0 && session.total > 0 {
                myPortion = session.total / Double(session.participants.count)
            } else {
                myPortion = session.total
            }
        } else {
            myPortion = session.total
        }

        guard myPortion > 0 else {
            expenses.removeAll { $0.splitSessionId == session.id }
            return
        }

        let billTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Makan Bareng"
            : session.title.trimmingCharacters(in: .whitespacesAndNewlines)

        let otherCount = max(0, session.participants.count - 1)
        let note = otherCount > 0 ? "Split bill dengan \(otherCount) orang" : "Tagihan bersama"

        if let existingIdx = expenses.firstIndex(where: { $0.splitSessionId == session.id }) {
            expenses[existingIdx].title = billTitle
            expenses[existingIdx].amount = myPortion
            expenses[existingIdx].date = session.date
            expenses[existingIdx].note = note
            expenses[existingIdx].inputMethod = .splitBill
        } else {
            let expense = Expense(
                title: billTitle,
                amount: myPortion,
                category: .food,
                date: session.date,
                note: note,
                inputMethod: .splitBill,
                splitSessionId: session.id
            )
            expenses.insert(expense, at: 0)
        }
    }

    func syncAllSplitSessions() {
        for session in splitSessions {
            syncExpenseForSplitSession(session)
        }
    }

    func clearAllData() {
        expenses.removeAll()
        splitSessions.removeAll()
        saveToStorage()
        saveSplitSessionsToStorage()
        savingsAI.invalidate()
    }

    func resetToDemoData() {
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now) ?? now

        expenses = [
            Expense(title: "Makan Siang Soto Betawi", amount: 45_000, category: .food, date: now, note: "Makan siang kantor", inputMethod: .manual),
            Expense(title: "Kopi Kenangan Mantan", amount: 28_000, category: .food, date: now, note: "Pesan via voice input", inputMethod: .voice),
            Expense(title: "Bensin Pertamax", amount: 100_000, category: .transport, date: yesterday, note: "Isi bensin motor", inputMethod: .manual),
            Expense(title: "Belanja Supermarket", amount: 185_000, category: .shopping, date: yesterday, note: "Scan struk kasir", inputMethod: .receiptScanner),
            Expense(title: "Nongkrong Cafe & Snack", amount: 120_000, category: .entertainment, date: twoDaysAgo, note: "Patungan teman", inputMethod: .manual),
            Expense(title: "Paket Data Internet", amount: 75_000, category: .bills, date: twoDaysAgo, note: "Bulanan", inputMethod: .manual)
        ]
    }

    private func cleanDummyDataIfNeeded() {
        guard !defaults.bool(forKey: dummyCleanedKey) else { return }

        let dummyTitles: Set<String> = [
            "Makan Siang Soto Betawi",
            "Kopi Kenangan Mantan",
            "Bensin Pertamax",
            "Belanja Supermarket",
            "Nongkrong Cafe & Snack",
            "Paket Data Internet"
        ]

        let initialExpenseCount = expenses.count
        expenses.removeAll { dummyTitles.contains($0.title) }
        if expenses.count != initialExpenseCount {
            saveToStorage()
        }

        let initialSplitCount = splitSessions.count
        splitSessions.removeAll { session in
            session.title == "Makan Bareng" &&
            session.participants.map(\.name).sorted() == ["Budi", "Citra", "Rina"]
        }
        if splitSessions.count != initialSplitCount {
            saveSplitSessionsToStorage()
        }

        if userName == "Rina" {
            userName = "Teman Dooit"
        }

        defaults.set(true, forKey: dummyCleanedKey)
    }

    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(expenses) {
            defaults.set(encoded, forKey: storageKey)
        }
    }

    private func loadFromStorage() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Expense].self, from: data) {
            self.expenses = decoded
        } else {
            self.expenses = []
        }
    }

    private func saveSplitSessionsToStorage() {
        if let encoded = try? JSONEncoder().encode(splitSessions) {
            defaults.set(encoded, forKey: splitSessionsKey)
        }
    }

    private func loadSplitSessionsFromStorage() {
        if let data = defaults.data(forKey: splitSessionsKey),
           let decoded = try? JSONDecoder().decode([SplitBillSession].self, from: data) {
            self.splitSessions = decoded
        } else {
            self.splitSessions = []
        }
    }
}
