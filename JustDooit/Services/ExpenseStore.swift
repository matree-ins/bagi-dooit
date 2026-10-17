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
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let savedName = defaults.string(forKey: "UserNameKey"), !savedName.isEmpty {
            self.userName = savedName
        } else {
            self.userName = "Rina"
        }
        if let savedBudget = defaults.value(forKey: "DailyBudgetLimitKey") as? Double, savedBudget > 0 {
            self.dailyBudgetLimit = savedBudget
        }
        loadFromStorage()
        loadSplitSessionsFromStorage()
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
        for index in offsets.sorted(by: >) {
            expenses.remove(at: index)
        }
    }

    func deleteExpense(id: UUID) {
        expenses.removeAll { $0.id == id }
    }

    func addSplitSession(_ session: SplitBillSession) {
        if let idx = splitSessions.firstIndex(where: { $0.id == session.id }) {
            splitSessions[idx] = session
        } else {
            splitSessions.insert(session, at: 0)
        }
    }

    func updateSplitSession(_ session: SplitBillSession) {
        if let idx = splitSessions.firstIndex(where: { $0.id == session.id }) {
            splitSessions[idx] = session
        }
    }

    func deleteSplitSession(id: UUID) {
        splitSessions.removeAll { $0.id == id }
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
            // Seed with rich realistic demo data for mini hackathon
            resetToDemoData()
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
            let rina = SplitParticipant(name: "Rina", phoneNumber: "")
            let budi = SplitParticipant(name: "Budi", phoneNumber: "081234567890", isPaid: false)
            let citra = SplitParticipant(name: "Citra", phoneNumber: "085712345678", isPaid: false)

            let item1 = SplitItem(name: "Nasi Goreng Spesial", price: 35_000, quantity: 2, assignedParticipantIds: [rina.id, budi.id])
            let item2 = SplitItem(name: "Ayam Bakar Madu", price: 42_000, quantity: 1, assignedParticipantIds: [citra.id])
            let item3 = SplitItem(name: "Es Teh Manis", price: 8_000, quantity: 3, assignedParticipantIds: [rina.id, budi.id, citra.id])

            let demoSession = SplitBillSession(
                title: "Makan Bareng",
                date: Date(),
                participants: [rina, budi, citra],
                items: [item1, item2, item3],
                taxPercentage: 10,
                servicePercentage: 5
            )
            self.splitSessions = [demoSession]
        }
    }
}
