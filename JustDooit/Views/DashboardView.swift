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

                    // Feature 2: Financial Behaviour Suggestion Card
                    FinancialBehaviorCard(expenseStore: expenseStore)

                    // Quick Actions
                    quickActionButtons

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
            .navigationTitle("JustDooit 💸")
            .searchable(text: $searchText, prompt: "Cari transaksi...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.blue)
                    Text("Hari Ini")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(CurrencyFormatter.format(expenseStore.totalExpensesToday))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .foregroundStyle(.purple)
                    Text("Total Tercatat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(CurrencyFormatter.format(expenseStore.totalExpensesAllTime))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Quick Action Buttons
    private var quickActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { showAddSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                    Text("Catat Baru")
                        .font(.footnote)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.blue.opacity(0.25), radius: 5, x: 0, y: 3)
            }

            Button(action: { onNavigateToSplitBill?() }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.subheadline)
                    Text("Split Bill & WA")
                        .font(.footnote)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color(red: 0.1, green: 0.7, blue: 0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.green.opacity(0.25), radius: 5, x: 0, y: 3)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
            Text("Belum ada pengeluaran")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Supporting Row & Pill Views
private struct FilterPill: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

private struct ExpenseRowView: View {
    let expense: Expense
    let onDelete: () -> Void

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = Locale(identifier: "id_ID")
        return df
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon Badge
            Circle()
                .fill(expense.category.color.opacity(0.18))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: expense.category.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(expense.category.color)
                )

            // Title & Details
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(dateFormatter.string(from: expense.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // Input Method Tag
                    HStack(spacing: 2) {
                        Image(systemName: expense.inputMethod.icon)
                        Text(expense.inputMethod.rawValue)
                    }
                    .font(.system(size: 9))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
                }
            }

            Spacer()

            // Amount
            Text(CurrencyFormatter.format(expense.amount))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.7))
            }
            .padding(.leading, 4)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
