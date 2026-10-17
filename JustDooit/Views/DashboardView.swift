//
//  DashboardView.swift
//  JustDooit
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var expenseStore: ExpenseStore
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
                        // MARK: - Greeting Header ("Halo, Rina. / Mau bagi tagihan apa hari ini?")
                        headerGreetingView
                            .padding(.top, 8)

                        // MARK: - Card "Belum selesai" (Blue Card)
                        unpaidCardView

                        // MARK: - Button "+ Buat Tagihan"
                        createBillButton

                        // MARK: - Section "Split bill terbaru"
                        recentSplitBillsSection
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
                    .id(quickEntry?.id)
            }
            .sheet(item: $selectedSplitSession, onDismiss: presentPendingEntry) { session in
                NavigationStack {
                    SplitBillView(expenseStore: expenseStore, initialSession: session, onComplete: { selectedSplitSession = nil }, isDetailMode: true)
                }
            }
            .sheet(isPresented: $showProfileSheet, onDismiss: presentPendingEntry) {
                ProfileView(expenseStore: expenseStore, onShowOnboarding: onShowOnboarding)
            }
            .task(id: quickEntry?.id) {
                guard quickEntry != nil else { return }
                if showProfileSheet { showProfileSheet = false }
                else if selectedSplitSession != nil { selectedSplitSession = nil }
                else { showAddSheet = true }
            }
        }
    }

    private func presentPendingEntry() {
        guard quickEntry != nil else { return }
        showAddSheet = true
    }

    // MARK: - Header Greeting View
    private var headerGreetingView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Halo, \(expenseStore.userName).")
                .font(.title.bold())
                .foregroundStyle(BagiTheme.ink)

            Text("Mau bagi tagihan apa hari ini?")
                .font(.subheadline)
                .foregroundStyle(BagiTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Card "Belum selesai" (Blue Card)
    private var unpaidCardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Belum selesai")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.85))

            Text(unpaidTotalAmount > 0 ? formatRp(unpaidTotalAmount) : "Rp0")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

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

    // MARK: - Section "Split bill terbaru"
    private var recentSplitBillsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Split bill terbaru")
                .font(.title3.bold())
                .foregroundStyle(BagiTheme.ink)

            if expenseStore.splitSessions.isEmpty {
                ContentUnavailableView("Belum ada split bill", systemImage: "receipt", description: Text("Buat tagihan untuk mulai berbagi pengeluaran."))
                    .frame(maxWidth: .infinity)
                    .background(BagiTheme.surface, in: .rect(cornerRadius: BagiTheme.radius))
            } else {
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
    }
}
