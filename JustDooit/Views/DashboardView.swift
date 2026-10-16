//
//  DashboardView.swift
//  JustDooit
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var expenseStore: ExpenseStore
    var onNavigateToSplitBill: (() -> Void)? = nil

    @State private var showAddSheet: Bool = false
    @State private var selectedCategoryFilter: ExpenseCategory? = nil
    @State private var searchText: String = ""

    var filteredExpenses: [Expense] {
        expenseStore.expenses.filter { expense in
            let matchesCategory = selectedCategoryFilter == nil || expense.category == selectedCategoryFilter
            let matchesSearch = searchText.isEmpty || expense.title.localizedCaseInsensitiveContains(searchText) || expense.note.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Summary Header
                    headerSummaryCards

                    // Existing actions stay prominent; advice details can be expanded.
                    quickActionButtons

                    FinancialBehaviorCard(expenseStore: expenseStore)

                    // Expense Filter & List Header
                    expenseListHeader

                    // Expense List
                    if filteredExpenses.isEmpty {
                        emptyStateView
                    } else {
                        expenseListView
                    }
                }
                .padding()
                .padding(.bottom, 30)
            }
            .bagiScreen()
            .navigationTitle("Bagi Dooit")
            .searchable(text: $searchText, prompt: "Cari transaksi...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(BagiTheme.primary)
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(role: .destructive, action: { expenseStore.resetToDemoData() }) {
                            Label("Reset Data Demo", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.subheadline)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddExpenseSheet(expenseStore: expenseStore)
            }
        }
    }

    // MARK: - Header Summary Cards
    private var headerSummaryCards: some View {
        ExpenseSummaryCard(today: expenseStore.totalExpensesToday, total: expenseStore.totalExpensesAllTime)
    }

    // MARK: - Quick Action Buttons
    private var quickActionButtons: some View {
        VStack(spacing: 12) {
            DashboardActionTile(title: "Catat pengeluaran", subtitle: "Manual, suara, atau scan struk", symbol: "plus") {
                showAddSheet = true
            }
            DashboardActionTile(title: "Bagi tagihan", subtitle: "Pilih pesanan dan temanmu", symbol: "person.2") {
                onNavigateToSplitBill?()
            }
        }
    }

    // MARK: - List Header & Filters
    private var expenseListHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Riwayat Transaksi")
                    .font(.headline)
                Spacer()
                Text("\(filteredExpenses.count) transaksi")
                    .font(.footnote)
                    .foregroundStyle(BagiTheme.muted)
            }

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterPill(title: "Semua", isSelected: selectedCategoryFilter == nil) {
                        selectedCategoryFilter = nil
                    }

                    ForEach(ExpenseCategory.allCases) { cat in
                        FilterPill(
                            title: cat.rawValue,
                            icon: cat.icon,
                            isSelected: selectedCategoryFilter == cat
                        ) {
                            selectedCategoryFilter = cat
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Expense List View
    private var expenseListView: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredExpenses) { expense in
                ExpenseRowView(expense: expense) {
                    expenseStore.deleteExpense(id: expense.id)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(BagiTheme.muted)
            Text("Belum ada pengeluaran")
                .font(.subheadline)
                .foregroundStyle(BagiTheme.muted)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Supporting Row & Pill Views
