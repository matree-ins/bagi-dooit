//
//  ProfileView.swift
//  JustDooit
//

import SwiftUI

struct ProfileView: View {
    @Bindable var expenseStore: ExpenseStore
    var onShowOnboarding: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showingResetAlert: Bool = false
    @State private var manualBudgetText: String = ""

    private let budgetPresets: [Double] = [50_000, 100_000, 150_000, 250_000, 500_000]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Section 1: Identitas Profil (HIG Standard Account Row)
                Section {
                    HStack(spacing: 16) {
                        avatarView
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Nama Anda", text: $expenseStore.userName)
                                .font(.headline)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.done)

                            Text("Digunakan untuk sapaan & pesan bagi tagihan")
                                .font(.caption)
                                .foregroundStyle(BagiTheme.muted)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Identitas")
                }

                // MARK: - Section 2: Target Anggaran Harian
                Section {
                    // Manual Nominal Input Field
                    HStack {
                        Text("Nominal Target")
                            .font(.subheadline)
                            .foregroundStyle(BagiTheme.ink)

                        Spacer()

                        HStack(spacing: 4) {
                            Text("Rp")
                                .font(.subheadline.bold())
                                .foregroundStyle(BagiTheme.primary)

                            TextField("150000", text: $manualBudgetText)
                                .keyboardType(.numberPad)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(BagiTheme.primary)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 90, maxWidth: 140)
                                .onChange(of: manualBudgetText) { _, newValue in
                                    let digits = newValue.filter { $0.isNumber }
                                    if let val = Double(digits), val > 0 {
                                        if val != expenseStore.dailyBudgetLimit {
                                            expenseStore.dailyBudgetLimit = val
                                        }
                                    }
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(BagiTheme.soft)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.vertical, 2)

                    // Slider Adjustment
                    VStack(alignment: .leading, spacing: 6) {
                        Slider(
                            value: Binding(
                                get: { min(max(expenseStore.dailyBudgetLimit, 25_000), 1_000_000) },
                                set: { newValue in
                                    expenseStore.dailyBudgetLimit = newValue
                                    manualBudgetText = String(Int(newValue))
                                }
                            ),
                            in: 25_000...1_000_000,
                            step: 25_000
                        )
                        .tint(BagiTheme.primary)
                        .accessibilityLabel("Batas Anggaran Harian")
                        .accessibilityValue(CurrencyFormatter.format(expenseStore.dailyBudgetLimit))

                        HStack {
                            Text("Rp 25.000")
                                .font(.footnote)
                                .foregroundStyle(BagiTheme.muted)
                            Spacer()
                            Text("Rp 1.000.000")
                                .font(.footnote)
                                .foregroundStyle(BagiTheme.muted)
                        }
                    }
                    .padding(.vertical, 2)

                    // Quick Preset Buttons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pilihan Cepat:")
                            .font(.caption)
                            .foregroundStyle(BagiTheme.muted)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(budgetPresets, id: \.self) { preset in
                                    Button {
                                        expenseStore.dailyBudgetLimit = preset
                                        manualBudgetText = String(Int(preset))
                                    } label: {
                                        Text(CurrencyFormatter.format(preset))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(expenseStore.dailyBudgetLimit == preset ? BagiTheme.action : BagiTheme.soft)
                                            .foregroundStyle(expenseStore.dailyBudgetLimit == preset ? .white : BagiTheme.ink)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Batas Anggaran Harian")
                } footer: {
                    Text("Anggaran ini dibandingkan dengan rata-rata harian dari catatan pengeluaran bulan ini.")
                }

                // MARK: - Section 3: Preferensi & Data
                Section {
                    Button {
                        dismiss()
                        onShowOnboarding?()
                    } label: {
                        Label {
                            Text("Buka Panduan Onboarding")
                                .foregroundStyle(BagiTheme.ink)
                        } icon: {
                            Image(systemName: "sparkles")
                                .foregroundStyle(BagiTheme.primary)
                        }
                    }

                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Hapus Semua Data", systemImage: "trash")
                    }
                } header: {
                    Text("Preferensi & Data")
                }

                // MARK: - Section 4: Tentang Aplikasi
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Bagi Dooit")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(BagiTheme.ink)
                            Text("Versi 1.0 • Makan bareng, bayar sesuai porsi")
                                .font(.footnote)
                                .foregroundStyle(BagiTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(BagiTheme.background)
            .navigationTitle("Profil & Pengaturan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Selesai") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(BagiTheme.primary)
                }
            }
            .alert("Hapus Semua Data?", isPresented: $showingResetAlert) {
                Button("Batal", role: .cancel) {}
                Button("Hapus", role: .destructive) {
                    expenseStore.clearAllData()
                    dismiss()
                }
            } message: {
                Text("Semua riwayat transaksi dan catatan split bill akan dihapus secara permanen.")
            }
            .onAppear {
                manualBudgetText = String(Int(expenseStore.dailyBudgetLimit))
            }
        }
    }

    // MARK: - Avatar Subview
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(BagiTheme.primary.opacity(0.12))
                .frame(width: 56, height: 56)

            if let firstChar = expenseStore.userName.first, !expenseStore.userName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(String(firstChar).uppercased())
                    .font(.title3.bold())
                    .foregroundStyle(BagiTheme.primary)
            } else {
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundStyle(BagiTheme.primary)
            }
        }
    }
}

#Preview {
    ProfileView(expenseStore: ExpenseStore())
}
