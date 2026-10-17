//
//  HistoryView.swift
//  JustDooit
//

import SwiftUI
import Charts

enum HistoryPeriod: String, CaseIterable, Identifiable {
    case today = "Hari Ini"
    case sevenDays = "7 Hari"
    case thisMonth = "Bulan Ini"
    case all = "Semua"

    var id: String { rawValue }
}

enum ChartType: String, CaseIterable, Identifiable {
    case timeTrend = "Tren Waktu"
    case category = "Kategori"

    var id: String { rawValue }
}

struct TimeChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let date: Date
}

struct CategoryChartDataPoint: Identifiable {
    let id = UUID()
    let category: ExpenseCategory
    let amount: Double
    let percentage: Double
}

struct HistoryView: View {
    var expenseStore: ExpenseStore
    var onShowOnboarding: (() -> Void)? = nil

    @State private var searchText: String = ""
    @State private var selectedCategory: ExpenseCategory? = nil
    @State private var selectedPeriod: HistoryPeriod = .thisMonth
    @State private var selectedChartType: ChartType = .timeTrend
    @State private var showAddSheet: Bool = false
    @State private var showProfileSheet: Bool = false
    @State private var selectedSplitSession: SplitBillSession? = nil
    @State private var expenseToDelete: Expense? = nil
    @State private var showDeleteConfirmation: Bool = false

    private func formatRp(_ amount: Double) -> String {
        CurrencyFormatter.format(amount).replacingOccurrences(of: " ", with: "")
    }

    private func formatCompactAmount(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "%.1fJt", amount / 1_000_000).replacingOccurrences(of: ".0", with: "")
        } else if amount >= 1_000 {
            return String(format: "%.0frb", amount / 1_000)
        } else {
            return String(format: "%.0f", amount)
        }
    }

    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()

        return expenseStore.expenses.filter { expense in
            let matchesCategory = selectedCategory == nil || expense.category == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                expense.title.localizedCaseInsensitiveContains(searchText) ||
                expense.note.localizedCaseInsensitiveContains(searchText)

            let matchesPeriod: Bool
            switch selectedPeriod {
            case .today:
                matchesPeriod = calendar.isDateInToday(expense.date)
            case .sevenDays:
                if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) {
                    matchesPeriod = expense.date >= sevenDaysAgo
                } else {
                    matchesPeriod = true
                }
            case .thisMonth:
                matchesPeriod = calendar.isDate(expense.date, equalTo: now, toGranularity: .month)
            case .all:
                matchesPeriod = true
            }

            return matchesCategory && matchesSearch && matchesPeriod
        }
    }

    private var totalFilteredAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    private var averageExpense: Double {
        guard !filteredExpenses.isEmpty else { return 0 }
        return totalFilteredAmount / Double(filteredExpenses.count)
    }

    private var highestExpense: Expense? {
        filteredExpenses.max(by: { $0.amount < $1.amount })
    }

    // Time-based aggregation for charts
    private var timeChartData: [TimeChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .today, .all:
            let today = calendar.startOfDay(for: now)
            let slots: [(label: String, startHour: Int, endHour: Int)] = [
                ("Pagi", 6, 12),
                ("Siang", 12, 15),
                ("Sore", 15, 18),
                ("Malam", 18, 24)
            ]
            return slots.map { slot in
                let sum = filteredExpenses.filter { exp in
                    let h = calendar.component(.hour, from: exp.date)
                    return h >= slot.startHour && h < slot.endHour
                }.reduce(0) { $0 + $1.amount }
                return TimeChartDataPoint(label: slot.label, amount: sum, date: today)
            }

        case .sevenDays:
            let today = calendar.startOfDay(for: now)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "id_ID")
            formatter.dateFormat = "EEE"

            var points: [TimeChartDataPoint] = []
            for dayOffset in (0..<7).reversed() {
                if let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                    let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                    let sum = filteredExpenses.filter { $0.date >= day && $0.date < nextDay }.reduce(0) { $0 + $1.amount }
                    let label = calendar.isDateInToday(day) ? "Hari ini" : formatter.string(from: day)
                    points.append(TimeChartDataPoint(label: label, amount: sum, date: day))
                }
            }
            return points

        case .thisMonth:
            let dayCount = calendar.component(.day, from: now)
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

            var points: [TimeChartDataPoint] = []
            let step = max(1, dayCount / 7)
            for dayNum in stride(from: 1, through: dayCount, by: step) {
                if let day = calendar.date(byAdding: .day, value: dayNum - 1, to: startOfMonth) {
                    let intervalEnd = calendar.date(byAdding: .day, value: step, to: day) ?? now
                    let sum = filteredExpenses.filter { $0.date >= day && $0.date < intervalEnd }.reduce(0) { $0 + $1.amount }
                    points.append(TimeChartDataPoint(label: "\(dayNum)", amount: sum, date: day))
                }
            }
            return points
        }
    }

    private var categoryChartData: [CategoryChartDataPoint] {
        let total = totalFilteredAmount
        guard total > 0 else { return [] }
        var map: [ExpenseCategory: Double] = [:]
        for exp in filteredExpenses {
            map[exp.category, default: 0] += exp.amount
        }
        return map.sorted(by: { $0.value > $1.value }).map { cat, amount in
            CategoryChartDataPoint(
                category: cat,
                amount: amount,
                percentage: (amount / total) * 100
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#F7F8FB")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // MARK: - Header
                        headerView
                            .padding(.top, 8)

                        // MARK: - Blue Hero Overview Card
                        blueOverviewCard

                        // MARK: - Period Selector Pills
                        periodSelector

                        // MARK: - Statistics & Charts Card
                        statisticsChartCard

                        // MARK: - Search & Category Filters
                        filterSection

                        // MARK: - Transactions List
                        transactionsSection
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
            .sheet(isPresented: $showProfileSheet) {
                ProfileView(expenseStore: expenseStore, onShowOnboarding: onShowOnboarding)
            }
            .sheet(isPresented: $showAddSheet) {
                AddExpenseSheet(expenseStore: expenseStore)
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
            .alert("Hapus Pengeluaran", isPresented: $showDeleteConfirmation, presenting: expenseToDelete) { expense in
                Button("Batal", role: .cancel) { }
                Button("Hapus", role: .destructive) {
                    expenseStore.deleteExpense(id: expense.id)
                }
            } message: { expense in
                Text("Apakah Anda yakin ingin menghapus catatan '\(expense.title)' sebesar \(formatRp(expense.amount))?")
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Riwayat & Statistik")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            Text("Pantau grafik pengeluaran dan catatan transaksimu")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "#6B7280"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Blue Overview Card
    private var blueOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Total Pengeluaran (\(selectedPeriod.rawValue))")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))

            Text(formatRp(totalFilteredAmount))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.white)

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(filteredExpenses.count) transaksi")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.white.opacity(0.9))

                Text("•")
                    .foregroundStyle(Color.white.opacity(0.5))

                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Rata-rata \(formatCompactAmount(averageExpense))/transaksi")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.white.opacity(0.9))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "#3A6CFF"), Color(hex: "#2F5CE0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "#3A6CFF").opacity(0.22), radius: 10, x: 0, y: 5)
    }

    // MARK: - Period Selector
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HistoryPeriod.allCases) { period in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPeriod = period
                        }
                    }) {
                        Text(period.rawValue)
                            .font(.system(size: 13, weight: selectedPeriod == period ? .semibold : .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedPeriod == period ? Color(hex: "#3A6CFF") : Color.white)
                            .foregroundStyle(selectedPeriod == period ? Color.white : Color(hex: "#4B5563"))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(selectedPeriod == period ? 0.08 : 0.03), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Statistics & Chart Card
    private var statisticsChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart Type Switcher Header
            HStack {
                Text("Analisis Visual")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#111827"))

                Spacer()

                // Segmented picker
                HStack(spacing: 4) {
                    ForEach(ChartType.allCases) { type in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedChartType = type
                            }
                        }) {
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: selectedChartType == type ? .semibold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedChartType == type ? Color(hex: "#3A6CFF") : Color.clear)
                                .foregroundStyle(selectedChartType == type ? Color.white : Color(hex: "#6B7280"))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color(hex: "#F3F4F6"))
                .clipShape(Capsule())
            }

            if filteredExpenses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                    Text("Belum ada data grafik di periode ini")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
            } else {
                switch selectedChartType {
                case .timeTrend:
                    timeTrendChart
                case .category:
                    categoryBreakdownChart
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Time Trend Bar Chart
    private var timeTrendChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(timeChartData) { item in
                    BarMark(
                        x: .value("Waktu", item.label),
                        y: .value("Nominal", item.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#3A6CFF"), Color(hex: "#60A5FA")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color(hex: "#E5E7EB"))
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(formatCompactAmount(d))
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "#9CA3AF"))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
            }
            .frame(height: 170)
        }
    }

    // MARK: - Category Breakdown Chart
    private var categoryBreakdownChart: some View {
        VStack(spacing: 16) {
            // Donut chart
            Chart(categoryChartData) { item in
                SectorMark(
                    angle: .value("Nominal", item.amount),
                    innerRadius: .ratio(0.62),
                    angularInset: 2.0
                )
                .foregroundStyle(item.category.color)
                .cornerRadius(4)
            }
            .frame(height: 160)
            .overlay {
                VStack(spacing: 2) {
                    Text("Total")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                    Text(formatCompactAmount(totalFilteredAmount))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#111827"))
                }
            }

            // Category breakdown rows
            VStack(spacing: 10) {
                ForEach(categoryChartData) { item in
                    VStack(spacing: 6) {
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.category.color)
                                    .frame(width: 10, height: 10)
                                Text(item.category.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color(hex: "#111827"))
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                Text(formatRp(item.amount))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color(hex: "#111827"))

                                Text(String(format: "%.0f%%", item.percentage))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(item.category.color)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(item.category.color.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: "#F3F4F6"))
                                    .frame(height: 5)
                                Capsule()
                                    .fill(item.category.color)
                                    .frame(width: geo.size.width * CGFloat(item.percentage / 100), height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }
        }
    }

    // MARK: - Search & Filter Section
    private var filterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "#9CA3AF"))

                TextField("Cari catatan atau judul...", text: $searchText)
                    .font(.system(size: 14))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "#9CA3AF"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All Pill
                    Button(action: { selectedCategory = nil }) {
                        Text("Semua Kategori")
                            .font(.system(size: 12, weight: selectedCategory == nil ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == nil ? Color(hex: "#111827") : Color.white)
                            .foregroundStyle(selectedCategory == nil ? Color.white : Color(hex: "#4B5563"))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)

                    ForEach(ExpenseCategory.allCases) { cat in
                        Button(action: {
                            if selectedCategory == cat {
                                selectedCategory = nil
                            } else {
                                selectedCategory = cat
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10))
                                Text(cat.rawValue)
                                    .font(.system(size: 12, weight: selectedCategory == cat ? .semibold : .regular))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == cat ? cat.color : Color.white)
                            .foregroundStyle(selectedCategory == cat ? Color.white : Color(hex: "#4B5563"))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Transactions Section
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daftar Transaksi")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#111827"))

                Spacer()

                Text("\(filteredExpenses.count) ditemukan")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#6B7280"))
            }

            if filteredExpenses.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredExpenses) { expense in
                        transactionCard(for: expense)
                    }
                }
            }
        }
    }

    // MARK: - Transaction Card
    private func transactionCard(for expense: Expense) -> some View {
        HStack(spacing: 12) {
            // Category Icon Badge
            ZStack {
                Circle()
                    .fill(expense.category.color.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: expense.category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(expense.category.color)
            }

            // Info (Title, Date, Input Method Badge)
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#111827"))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(expense.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#6B7280"))

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#9CA3AF"))

                    HStack(spacing: 3) {
                        Image(systemName: expense.inputMethod.icon)
                            .font(.system(size: 10))
                        Text(expense.inputMethod.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "#4B5563"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#F3F4F6"))
                    .clipShape(Capsule())
                }

                if !expense.note.isEmpty {
                    Text(expense.note)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount & Delete action / Split Bill detail button
            VStack(alignment: .trailing, spacing: 6) {
                Text(formatRp(expense.amount))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#111827"))

                HStack(spacing: 6) {
                    if expense.splitSessionId != nil {
                        Button(action: {
                            if let sessionId = expense.splitSessionId,
                               let session = expenseStore.splitSessions.first(where: { $0.id == sessionId }) {
                                selectedSplitSession = session
                            }
                        }) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 13))
                                .foregroundStyle(BagiTheme.primary)
                                .padding(6)
                                .background(BagiTheme.primary.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: {
                        expenseToDelete = expense
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#EF4444"))
                            .padding(6)
                            .background(Color(hex: "#FEE2E2"))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if let sessionId = expense.splitSessionId,
               let session = expenseStore.splitSessions.first(where: { $0.id == sessionId }) {
                selectedSplitSession = session
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 38))
                .foregroundStyle(Color(hex: "#9CA3AF"))

            Text("Tidak ada transaksi")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: "#111827"))

            Text("Sesuaikan filter atau catat transaksi baru")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "#6B7280"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    HistoryView(expenseStore: ExpenseStore())
}
