//
//  ContentView.swift
//  JustDooit
//
//  Created by Training-61 on 16/10/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var expenseStore = ExpenseStore()
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Beranda", systemImage: "house.fill", value: AppTab.home) {
                DashboardView(expenseStore: expenseStore, onNavigateToSplitBill: {
                    selectedTab = .splitBill
                })
            }
            Tab("Bagi Tagihan", systemImage: "person.2.fill", value: AppTab.splitBill) {
                SplitBillView()
            }
            Tab("Tips Hemat", systemImage: "chart.pie.fill", value: AppTab.analytics) {
                AnalyticsView(expenseStore: expenseStore)
            }
        }
        .tint(BagiTheme.primary)
    }
}

#Preview {
    ContentView()
}
