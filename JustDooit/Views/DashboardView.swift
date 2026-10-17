//
//  DashboardView.swift
//  JustDooit
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var expenseStore: ExpenseStore
    var onNavigateToHistory: (() -> Void)? = nil
    var onShowOnboarding: (() -> Void)? = nil

    @State private var showAddSheet: Bool = false
    @State private var showSplitBillSheet: Bool = false
    @State private var showProfileSheet: Bool = false

    private var recentExpenses: [Expense] {
        Array(expenseStore.expenses.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Summary Header
                    headerSummaryCards

                    // Quick Action Buttons (Horizontal Side-by-Side)
                    quickActionButtons

                    // Financial Health Behavior Card
                    FinancialBehaviorCard(expenseStore: expenseStore)

                    // Recent Expenses Section
                    recentExpensesSection
                }
                .padding()
                .padding(.bottom, 30)
            }
            .bagiScreen()
            .navigationTitle("Bagi Dooit")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showProfileSheet = true }) {
                        ZStack {
                            Circle()
                                .fill(BagiTheme.primary.opacity(0.12))
                                .frame(width: 36, height: 36)

                            if let firstChar = expenseStore.userName.first {
                                Text(String(firstChar).uppercased())
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(BagiTheme.primary)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(BagiTheme.primary)
                            }
                        }
                    }
                    .accessibilityLabel("Profil Pengguna")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddExpenseSheet(expenseStore: expenseStore)
            }
            .sheet(isPresented: $showSplitBillSheet) {
                SplitBillView()
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView(expenseStore: expenseStore, onShowOnboarding: onShowOnboarding)
            }
        }
    }

    // MARK: - Header Summary Cards
    private var headerSummaryCards: some View {
        ExpenseSummaryCard(today: expenseStore.totalExpensesToday, total: expenseStore.totalExpensesAllTime)
    }

    // MARK: - Quick Action Buttons
    private var quickActionButtons: some View {
        HStack(spacing: 12) {
            // Primary Button (Left): Catat Pengeluaran
            Button(action: { showAddSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                    Text("Catat Pengeluaran")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(BagiTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: BagiTheme.primary.opacity(0.2), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Secondary Button (Right): Split Bill
            Button(action: { showSplitBillSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Split Bill")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(BagiTheme.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(BagiTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BagiTheme.primary.opacity(0.3), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Recent Expenses Section
    private var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transaksi Terbaru")
                    .font(.headline)
                Spacer()
                if !expenseStore.expenses.isEmpty {
                    Button("Lihat Semua") {
                        onNavigateToHistory?()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(BagiTheme.primary)
                }
            }

            if recentExpenses.isEmpty {
                emptyRecentView
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(recentExpenses) { expense in
                        ExpenseRowView(expense: expense) {
                            expenseStore.deleteExpense(id: expense.id)
                        }
                    }
                }
            }
        }
    }

    private var emptyRecentView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(BagiTheme.muted)
            Text("Belum ada pengeluaran")
                .font(.subheadline)
                .foregroundStyle(BagiTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(BagiTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
    }
}

#Preview {
    DashboardView(expenseStore: ExpenseStore())
}
