//
//  ContentView.swift
//  JustDooit
//
//  Created by Training-61 on 16/10/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var expenseStore = ExpenseStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home

    @State private var quickEntry: QuickEntryRequest?
    @State private var pendingEntry: QuickEntryRequest?

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasCompletedOnboarding = true
                    }
                }
            } else {
                TabView(selection: $selectedTab) {
                    DashboardView(
                        expenseStore: expenseStore,
                        quickEntry: $quickEntry,
                        onNavigateToHistory: {
                            selectedTab = .history
                        },
                        onShowOnboarding: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                hasCompletedOnboarding = false
                            }
                        }
                    )
                    .tabItem {
                        Label("Beranda", systemImage: "house.fill")
                    }
                    .tag(AppTab.home)

                    HistoryView(
                        expenseStore: expenseStore,
                        onShowOnboarding: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                hasCompletedOnboarding = false
                            }
                        }
                    )
                    .tabItem {
                        Label("Riwayat", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(AppTab.history)

                    AnalyticsView(
                        expenseStore: expenseStore,
                        onShowOnboarding: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                hasCompletedOnboarding = false
                            }
                        }
                    )
                    .tabItem {
                        Label("Tips Hemat", systemImage: "chart.pie.fill")
                    }
                    .tag(AppTab.analytics)
                }
                .tint(BagiTheme.primary)
            }
        }
        .onOpenURL { url in
            guard let request = QuickEntryRequest(url: url) else { return }
            if hasCompletedOnboarding {
                selectedTab = .home
                quickEntry = request
            } else {
                pendingEntry = request
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, complete in
            if complete, let request = pendingEntry {
                pendingEntry = nil
                selectedTab = .home
                quickEntry = request
            }
        }
        .task(id: hasCompletedOnboarding) {
            guard hasCompletedOnboarding else { expenseStore.savingsAI.pause(); return }
            refreshSavings()
            while !Task.isCancelled {
                let now = Date()
                guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) else { return }
                do { try await Task.sleep(for: .seconds(max(1, nextDay.timeIntervalSinceNow + 1))) }
                catch { return }
                refreshSavings()
            }
        }
        .onChange(of: expenseStore.expenses) { _, _ in refreshSavings() }
        .onChange(of: expenseStore.dailyBudgetLimit) { _, _ in refreshSavings() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshSavings() }
            else if phase == .background { expenseStore.savingsAI.pause() }
        }
        .overlay(alignment: .top) {
            if let notice = expenseStore.savingsAI.errorNotice, hasCompletedOnboarding {
                SavingsErrorToast(notice: notice, onRetry: {
                    expenseStore.savingsAI.refresh(for: expenseStore.currentAdvice, force: true)
                }, onDismiss: { expenseStore.savingsAI.dismissError() })
                .id(notice.id)
                .padding(.top, 8)
            }
        }
    }

    private func refreshSavings() {
        guard hasCompletedOnboarding, scenePhase == .active else { return }
        expenseStore.refreshAnalysisDay()
        expenseStore.savingsAI.refresh(for: expenseStore.currentAdvice)
    }
}

#Preview("Main Content") {
    ContentView()
}

#Preview("Onboarding") {
    OnboardingView(onGetStarted: {})
}
