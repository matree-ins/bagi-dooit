//
//  ExpenseStore.swift
//  JustDooit
//

import SwiftUI
import Combine

class ExpenseStore: ObservableObject {
    @Published var userName: String = "Teman Dooit" {
        didSet {
            defaults.set(userName, forKey: "UserNameKey")
        }
    }

    @Published var expenses: [Expense] = [] {
        didSet {
            saveToStorage()
        }
    }

    @Published var dailyBudgetLimit: Double = 150_000 {
        didSet {
            defaults.set(dailyBudgetLimit, forKey: "DailyBudgetLimitKey")
        }
    }

    private let storageKey = "JustDooit_Expenses_v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let savedName = defaults.string(forKey: "UserNameKey"), !savedName.isEmpty {
            self.userName = savedName
        }
        if let savedBudget = defaults.value(forKey: "DailyBudgetLimitKey") as? Double, savedBudget > 0 {
            self.dailyBudgetLimit = savedBudget
        }
        loadFromStorage()
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
        expenses.remove(atOffsets: offsets)
    }

    func deleteExpense(id: UUID) {
        expenses.removeAll { $0.id == id }
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
}
