//
//  ContentView.swift
//  JustDooit
//
//  Created by Training-61 on 16/10/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var expenseStore = ExpenseStore()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(expenseStore: expenseStore, onNavigateToSplitBill: {
                selectedTab = 1
            })
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }
            .tag(0)

            SplitBillView()
                .tabItem {
                    Label("Split Bill", systemImage: "person.2.fill")
                }
                .tag(1)

            AnalyticsView(expenseStore: expenseStore)
                .tabItem {
                    Label("Tips Hemat", systemImage: "chart.pie.fill")
                }
                .tag(2)
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
}
