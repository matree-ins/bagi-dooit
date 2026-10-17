//
//  HistoryView.swift
//  JustDooit
//

import SwiftUI

enum HistoryPeriod: String, CaseIterable, Identifiable {
    case all = "Semua"
    case today = "Hari Ini"
    case sevenDays = "7 Hari"
    case thisMonth = "Bulan Ini"

    var id: String { rawValue }
}

struct HistoryView: View {
    @ObservedObject var expenseStore: ExpenseStore

    @State private var searchText: String = ""
    @State private var selectedCategory: ExpenseCategory? = nil
    @State private var selectedPeriod: HistoryPeriod = .all
    @State private var showAddSheet: Bool = false

    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()

        return expenseStore.expenses.filter { expense in
            // Period filter
            let matchesPeriod: Bool
            switch selectedPeriod {
            case .all:
                matchesPeriod = true
            case .today:
                matchesPeriod = calendar.isDateInToday(expense.date)
            case .sevenDays:
                if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) {
                    matchesPeriod = expense.date >= sevenDaysAgo
                } else {
                    matchesPeriod = true
                }
            case .thisMonth:
                matchesPeriod = calendar.isDate(expense.date, equalTo: now, toGranularity: .month)
            }

            // Category filter
            let matchesCategory = selectedCategory == nil || expense.category == selectedCategory

            // Search filter
            let matchesSearch = searchText.isEmpty ||
                expense.title.localizedCaseInsensitiveContains(searchText) ||
                expense.note.localizedCaseInsensitiveContains(searchText)

            return matchesPeriod && matchesCategory && matchesSearch
        }
    }

    private var totalFilteredAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    private var averageFilteredAmount: Double {
        guard !filteredExpenses.isEmpty else { return 0 }
        return totalFilteredAmount / Double(filteredExpenses.count)
    }

    private var topCategory: (category: ExpenseCategory, amount: Double)? {
        guard !filteredExpenses.isEmpty else { return nil }
        var map: [ExpenseCategory: Double] = [:]
        for exp in filteredExpenses {
            map[exp.category, default: 0] += exp.amount
        }
        guard let maxEntry = map.max(by: { $0.value < $1.value }) else { return nil }
        return (category: maxEntry.key, amount: maxEntry.value)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Statistics Overview Card
                    statisticsCard

                    // Period Selector
                    periodPicker

                    // Category Filter Pills
                    categoryFilters

                    // Transactions Section
                    transactionsSection
                }
                .padding()
                .padding(.bottom, 30)
            }
            .bagiScreen()
            .navigationTitle("Riwayat & Statistik")
            .searchable(text: $searchText, prompt: "Cari riwayat transaksi...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(BagiTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddExpenseSheet(expenseStore: expenseStore)
            }
        }
    }

    // MARK: - Statistics Card
    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Pengeluaran (\(selectedPeriod.rawValue))")
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                    Text(CurrencyFormatter.format(totalFilteredAmount))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(BagiTheme.ink)
                }
                Spacer()

                ZStack {
                    Circle()
                        .fill(BagiTheme.primary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundStyle(BagiTheme.primary)
                }
            }

            Divider()

            HStack(spacing: 10) {
                MetricMiniBox(
                    title: "Transaksi",
                    value: "\(filteredExpenses.count)",
                    color: BagiTheme.ink
                )

                MetricMiniBox(
                    title: "Rata-rata",
                    value: CurrencyFormatter.format(averageFilteredAmount),
                    color: BagiTheme.ink
                )

                if let topCat = topCategory {
                    MetricMiniBox(
                        title: "Terbesar",
                        value: topCat.category.rawValue,
                        color: topCat.category.color
                    )
                }
            }
        }
        .padding()
        .background(BagiTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
    }

    // MARK: - Period Picker
    private var periodPicker: some View {
        Picker("Periode", selection: $selectedPeriod) {
            ForEach(HistoryPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Category Filters
    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "Semua Kategori", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(ExpenseCategory.allCases) { cat in
                    FilterPill(
                        title: cat.rawValue,
                        icon: cat.icon,
                        isSelected: selectedCategory == cat
                    ) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Transactions Section
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daftar Transaksi")
                    .font(.headline)
                Spacer()
                Text("\(filteredExpenses.count) ditemukan")
                    .font(.footnote)
                    .foregroundStyle(BagiTheme.muted)
            }

            if filteredExpenses.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredExpenses) { expense in
                        ExpenseRowView(expense: expense) {
                            expenseStore.deleteExpense(id: expense.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(BagiTheme.muted)

            Text("Tidak ada transaksi")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(BagiTheme.ink)

            Text("Tidak ditemukan transaksi untuk filter atau pencarian saat ini.")
                .font(.footnote)
                .foregroundStyle(BagiTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .background(BagiTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
    }
}

#Preview {
    HistoryView(expenseStore: ExpenseStore())
}
