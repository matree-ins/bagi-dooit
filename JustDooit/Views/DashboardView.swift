//
//  DashboardView.swift
//  JustDooit
//

import SwiftUI

struct DashboardView: View {
    var expenseStore: ExpenseStore
    @Binding var quickEntry: QuickEntryRequest?
    var onNavigateToHistory: (() -> Void)? = nil
    var onShowOnboarding: (() -> Void)? = nil

    @State private var showAddSheet: Bool = false
    @State private var showProfileSheet: Bool = false
    @State private var selectedSplitSession: SplitBillSession? = nil

    private func formatRp(_ amount: Double) -> String {
        CurrencyFormatter.format(amount).replacingOccurrences(of: " ", with: "")
    }

    private var unpaidTotalAmount: Double {
        var total: Double = 0
        for session in expenseStore.splitSessions {
            for p in session.participants where p.name != "Saya" && !p.isPaid {
                total += session.participantTotal(for: p.id)
            }
        }
        return total
    }

    private var activePendingSession: SplitBillSession? {
        expenseStore.splitSessions.first { session in
            session.participants.contains { $0.name != "Saya" && !$0.isPaid }
        }
    }

    private var pendingSubtitle: String {
        if let session = activePendingSession {
            let unpaidCount = session.participants.filter { $0.name != "Saya" && !$0.isPaid }.count
            let title = session.title.isEmpty ? "Makan Bareng" : session.title
            return "\(title)\n\(unpaidCount) orang belum bayar"
        } else if let latest = expenseStore.splitSessions.first {
            let title = latest.title.isEmpty ? "Makan Bareng" : latest.title
            return "\(title)\nSemua sudah lunas"
        } else {
            return "Semua tagihan sudah beres"
        }
    }

    private var recentPersonalExpenses: [Expense] {
        expenseStore.expenses.filter { $0.splitSessionId == nil }
    }

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hari ini"
        } else if calendar.isDateInYesterday(date) {
            return "Kemarin"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "id_ID")
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }

    private func participantNamesSummary(for session: SplitBillSession) -> String {
        let names = session.participants.map { $0.name }
        if names.isEmpty { return "Tanpa peserta" }
        return names.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BagiTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // MARK: - Greeting Header ("Halo, Teman Dooit. / Mau bagi tagihan apa hari ini?")
                        headerGreetingView
                            .padding(.top, 8)

                        // MARK: - Card "Belum selesai" (Blue Card)
                        unpaidCardView

                        // MARK: - Button "+ Buat Tagihan"
                        createBillButton

                        // MARK: - Recent Activity Section
                        recentActivitySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showProfileSheet = true }) {
                        ZStack {
                            Circle()
                                .fill(BagiTheme.primary.opacity(0.12))
                                .frame(width: 36, height: 36)

                            if let firstChar = expenseStore.userName.first {
                                Text(String(firstChar).uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(BagiTheme.primary)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(BagiTheme.primary)
                            }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Profil Pengguna")
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: { quickEntry = nil }) {
                AddExpenseSheet(expenseStore: expenseStore, quickEntry: quickEntry)
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView(expenseStore: expenseStore, onShowOnboarding: onShowOnboarding)
            }
            .sheet(item: $selectedSplitSession) { session in
                NavigationStack {
                    SplitBillView(
                        expenseStore: expenseStore,
                        initialSession: session,
                        onComplete: { selectedSplitSession = nil },
                        isDetailMode: true
                    )
                }
            }
            .onAppear {
                if quickEntry != nil {
                    showAddSheet = true
                }
            }
            .onChange(of: quickEntry) { _, newValue in
                if newValue != nil {
                    showAddSheet = true
                }
            }
        }
    }

    // MARK: - Greeting Header
    private var headerGreetingView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Halo, \(expenseStore.userName).")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(BagiTheme.ink)

            Text("Mau bagi tagihan apa hari ini?")
                .font(.system(size: 16))
                .foregroundStyle(BagiTheme.muted)
        }
    }

    // MARK: - Card "Belum selesai" (Blue Card)
    private var unpaidCardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Belum selesai")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.85))

                Spacer()

                if unpaidTotalAmount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("Perlu ditagih")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                }
            }

            Text(formatRp(unpaidTotalAmount))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .contentTransition(.numericText())

            Text(pendingSubtitle)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [BagiTheme.action, BagiTheme.hero], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
        .shadow(color: BagiTheme.primary.opacity(0.22), radius: 10, x: 0, y: 5)
    }

    // MARK: - Button "+ Buat Tagihan"
    private var createBillButton: some View {
        Button(action: { showAddSheet = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.headline.bold())
                Text("Buat Tagihan")
                    .font(.headline.bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(BagiTheme.action)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: BagiTheme.primary.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Recent Activity
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if expenseStore.splitSessions.isEmpty && recentPersonalExpenses.isEmpty {
                ContentUnavailableView(
                    "Belum ada tagihan",
                    systemImage: "receipt",
                    description: Text("Catat pengeluaran pribadi atau bagi tagihan bareng teman.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(BagiTheme.surface, in: .rect(cornerRadius: BagiTheme.radius))
                .overlay(RoundedRectangle(cornerRadius: BagiTheme.radius).strokeBorder(BagiTheme.border, lineWidth: 0.5))
            } else {
                // Split Bills Section
                if !expenseStore.splitSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Split bill terbaru")
                                .font(.title3.bold())
                                .foregroundStyle(BagiTheme.ink)

                            Spacer()

                            if !recentPersonalExpenses.isEmpty {
                                Button("Riwayat") {
                                    onNavigateToHistory?()
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BagiTheme.action)
                            }
                        }

                        VStack(spacing: 12) {
                            ForEach(expenseStore.splitSessions) { session in
                                Button(action: {
                                    selectedSplitSession = session
                                }) {
                                    RecentBillRow(session: session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Recent Personal Expenses Section
                if !recentPersonalExpenses.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Pengeluaran terbaru")
                                .font(.title3.bold())
                                .foregroundStyle(BagiTheme.ink)

                            Spacer()

                            Button("Lihat Semua") {
                                onNavigateToHistory?()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BagiTheme.action)
                        }

                        VStack(spacing: 10) {
                            ForEach(recentPersonalExpenses.prefix(3)) { expense in
                                Button(action: {
                                    onNavigateToHistory?()
                                }) {
                                    recentExpenseCard(for: expense)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func recentExpenseCard(for expense: Expense) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(expense.category.color.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: expense.category.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(expense.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.headline)
                    .foregroundStyle(BagiTheme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(expense.date, format: .dateTime.day().month(.abbreviated))
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)

                    Text("•")
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted.opacity(0.6))

                    Text(expense.category.rawValue)
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatRp(expense.amount))
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(BagiTheme.ink)

                Text(expense.inputMethod.rawValue)
                    .font(.caption2.bold())
                    .foregroundStyle(BagiTheme.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(BagiTheme.soft)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BagiTheme.surface, in: .rect(cornerRadius: BagiTheme.radius))
        .overlay(RoundedRectangle(cornerRadius: BagiTheme.radius).strokeBorder(BagiTheme.border, lineWidth: 0.5))
    }
}
