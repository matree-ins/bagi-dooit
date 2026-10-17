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
            return "\(title) • \(unpaidCount) orang belum bayar"
        } else if let latest = expenseStore.splitSessions.first {
            let title = latest.title.isEmpty ? "Makan Bareng" : latest.title
            return "\(title) • Semua sudah lunas"
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
                Color(hex: "#F7F8FB")
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

                        // MARK: - Section "Tagihan terbaru"
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
                                .fill(Color(hex: "#3A6CFF").opacity(0.12))
                                .frame(width: 36, height: 36)

                            if let firstChar = expenseStore.userName.first {
                                Text(String(firstChar).uppercased())
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(hex: "#3A6CFF"))
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#3A6CFF"))
                            }
                        }
                    }
                    .accessibilityLabel("Profil Pengguna")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddExpenseSheet(expenseStore: expenseStore)
            }
            .sheet(item: $selectedSplitSession) { session in
                NavigationStack {
                    SplitBillView(expenseStore: expenseStore, initialSession: session, isDetailMode: true)
                }
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView(expenseStore: expenseStore, onShowOnboarding: onShowOnboarding)
            }
        }
    }

    // MARK: - Header Greeting View
    private var headerGreetingView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Halo, \(expenseStore.userName).")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            Text("Mau bagi tagihan apa hari ini?")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "#6B7280"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Card "Belum selesai" (Blue Card)
    private var unpaidCardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Belum selesai")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))

            Text(unpaidTotalAmount > 0 ? formatRp(unpaidTotalAmount) : "Rp0")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            Text(pendingSubtitle)
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#3A6CFF"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color(hex: "#3A6CFF").opacity(0.22), radius: 10, x: 0, y: 5)
    }

    // MARK: - Button "+ Buat Tagihan"
    private var createBillButton: some View {
        Button(action: { showAddSheet = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("Buat Tagihan")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(hex: "#3A6CFF"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color(hex: "#3A6CFF").opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section "Tagihan terbaru"
    private var recentSplitBillsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tagihan terbaru")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            if expenseStore.splitSessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                    Text("Belum ada tagihan terbaru")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            } else {
                VStack(spacing: 12) {
                    ForEach(expenseStore.splitSessions) { session in
                        Button(action: {
                            selectedSplitSession = session
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    Text(session.title.isEmpty ? "Makan Bareng" : session.title)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color(hex: "#111827"))
                                    Spacer()
                                    Text(formatRp(session.total))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color(hex: "#111827"))
                                }

                                Text("\(formattedDate(session.date)) • \(participantNamesSummary(for: session))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(hex: "#6B7280"))

                                let unpaidCount = session.participants.filter { $0.name != "Saya" && !$0.isPaid }.count
                                if unpaidCount > 0 {
                                    Text("Menunggu \(unpaidCount) pembayaran")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(hex: "#D97706"))
                                } else {
                                    Text("Semua lunas")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(hex: "#16A34A"))
                                }
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
