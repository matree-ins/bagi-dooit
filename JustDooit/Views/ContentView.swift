//
//  ContentView.swift
//  JustDooit
//
//  Created by Training-61 on 16/10/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @StateObject private var expenseStore = ExpenseStore()
    @State private var selectedTab: AppTab = .home

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

                    HistoryView(expenseStore: expenseStore)
                        .tabItem {
                            Label("Riwayat", systemImage: "clock.arrow.circlepath")
                        }
                        .tag(AppTab.history)

                    AnalyticsView(expenseStore: expenseStore)
                        .tabItem {
                            Label("Tips Hemat", systemImage: "chart.pie.fill")
                        }
                        .tag(AppTab.analytics)
                }
                .tint(BagiTheme.primary)
            }
        }
    }
}

#Preview("Main Content") {
    ContentView()
}

#Preview("Onboarding") {
    OnboardingView(onGetStarted: {})
}
