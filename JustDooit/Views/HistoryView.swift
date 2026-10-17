//
//  HistoryView.swift
//  JustDooit
//

import SwiftUI
import Charts

enum HistoryPeriod: String, CaseIterable, Identifiable {
    case thisMonth = "Bulan Ini"
    case sevenDays = "7 Hari"
    case today = "Hari Ini"
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

    // MARK: - Chart Data Computation
    private var timeChartData: [TimeChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .today:
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

        case .all:
            let grouped = Dictionary(grouping: filteredExpenses) { calendar.startOfDay(for: $0.date) }
            let sortedDates = grouped.keys.sorted()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "id_ID")
            formatter.dateFormat = "d MMM"

            let recentDates = sortedDates.suffix(7)
            if recentDates.isEmpty {
                return []
            }
            return recentDates.map { date in
                let sum = grouped[date]?.reduce(0) { $0 + $1.amount } ?? 0
                return TimeChartDataPoint(label: formatter.string(from: date), amount: sum, date: date)
            }
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
                .foregroundStyle(.white)

            // Mini statistics tags
            HStack(spacing: 8) {
                miniStatTag(title: "Transaksi", value: "\(filteredExpenses.count)")
                miniStatTag(title: "Rata-rata", value: formatCompactAmount(averageFilteredAmount))
                if let topCat = topCategory {
                    miniStatTag(title: "Terbanyak", value: topCat.category.rawValue)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#3A6CFF"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color(hex: "#3A6CFF").opacity(0.22), radius: 10, x: 0, y: 5)
    }

    private func miniStatTag(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Period Selector
    private var periodSelector: some View {
        HStack(spacing: 8) {
            ForEach(HistoryPeriod.allCases) { period in
                let isSelected = selectedPeriod == period
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : Color(hex: "#6B7280"))
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? Color(hex: "#3A6CFF") : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: isSelected ? Color(hex: "#3A6CFF").opacity(0.25) : Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Statistics & Chart Card
    private var statisticsChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart Header & Switcher
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Statistik Pengeluaran")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: "#111827"))
                    Text(selectedChartType == .timeTrend ? "Grafik pengeluaran berdasarkan waktu" : "Proporsi pengeluaran per kategori")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }

                Spacer()

                // Chart mode toggle
                HStack(spacing: 4) {
                    ForEach(ChartType.allCases) { type in
                        let isSelected = selectedChartType == type
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedChartType = type
                            }
                        }) {
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? Color(hex: "#3A6CFF") : Color(hex: "#6B7280"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isSelected ? Color(hex: "#3A6CFF").opacity(0.12) : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color(hex: "#F3F4F6"))
                .clipShape(Capsule())
            }

            // Chart Content
            if filteredExpenses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                    Text("Belum ada data pengeluaran untuk grafik")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
                if selectedChartType == .timeTrend {
                    timeTrendChart
                } else {
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
                ForEach(timeChartData) { point in
                    BarMark(
                        x: .value("Waktu", point.label),
                        y: .value("Nominal", point.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#3A6CFF"), Color(hex: "#60A5FA")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(5)
                }

                if averageFilteredAmount > 0 && timeChartData.count > 1 {
                    RuleMark(y: .value("Rata-rata", averageFilteredAmount))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Rata-rata")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: "#F59E0B"))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                }
            }
            .frame(height: 190)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let doubleVal = value.as(Double.self) {
                        AxisValueLabel {
                            Text(formatCompactAmount(doubleVal))
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "#9CA3AF"))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Color(hex: "#E5E7EB"))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let str = value.as(String.self) {
                            Text(str)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(hex: "#6B7280"))
                        }
                    }
                }
            }

            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: "#3A6CFF"))
                        .frame(width: 8, height: 8)
                    Text("Pengeluaran")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
                Spacer()
                HStack(spacing: 5) {
                    Rectangle()
                        .stroke(Color(hex: "#F59E0B"), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .frame(width: 14, height: 1.5)
                    Text("Garis Rata-rata")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Category Donut Chart & Breakdown
    private var categoryBreakdownChart: some View {
        VStack(spacing: 16) {
            // Donut Chart
            ZStack {
                Chart(categoryChartData) { item in
                    SectorMark(
                        angle: .value("Nominal", item.amount),
                        innerRadius: .ratio(0.65),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.category.color)
                    .cornerRadius(3)
                }
                .frame(height: 180)

                VStack(spacing: 2) {
                    Text("Total")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#6B7280"))
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
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)

            // Category Horizontal Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryFilterChip(title: "Semua Kategori", icon: nil, isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(ExpenseCategory.allCases) { cat in
                        categoryFilterChip(title: cat.rawValue, icon: cat.icon, isSelected: selectedCategory == cat) {
                            selectedCategory = cat
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func categoryFilterChip(title: String, icon: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? .white : Color(hex: "#4B5563"))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color(hex: "#3A6CFF") : Color.white)
            .clipShape(Capsule())
            .shadow(color: isSelected ? Color(hex: "#3A6CFF").opacity(0.2) : Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transactions Section
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {

                Spacer()

                Text("\(filteredExpenses.count) ditemukan")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#6B7280"))
            }

            if filteredExpenses.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
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

            // Amount & Delete action
            VStack(alignment: .trailing, spacing: 6) {
                Text(formatRp(expense.amount))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#111827"))

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
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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

            Text("Belum ada pengeluaran pada periode atau kata kunci filter ini.")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "#6B7280"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    HistoryView(expenseStore: ExpenseStore())
}
