import SwiftUI
import PhotosUI

struct ManualExpenseInputView: View {
    @Binding var title: String
    @Binding var amountText: String
    @Binding var category: ExpenseCategory
    @Binding var date: Date
    @Binding var note: String

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nama Pengeluaran")
                    .font(.subheadline)
                    .foregroundStyle(BagiTheme.muted)
                TextField("Contoh: Nasi Goreng, Bensin, Kopi", text: $title)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(BagiTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Nominal (Rp)")
                    .font(.subheadline)
                    .foregroundStyle(BagiTheme.muted)
                HStack {
                    Text("Rp")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(BagiTheme.muted)
                    TextField("0", text: $amountText)
                        .keyboardType(.numberPad)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(12)
                .background(BagiTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Quick Add amount chips
                HStack(spacing: 8) {
                    quickAmountButton(label: "+10rb", amount: 10_000)
                    quickAmountButton(label: "+25rb", amount: 25_000)
                    quickAmountButton(label: "+50rb", amount: 50_000)
                    quickAmountButton(label: "+100rb", amount: 100_000)
                }
                .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Kategori")
                    .font(.subheadline)
                    .foregroundStyle(BagiTheme.muted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Button(action: { self.category = cat }) {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                    Text(cat.rawValue)
                                }
                                .font(.footnote)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(category == cat ? cat.color.opacity(0.2) : BagiTheme.surface)
                                .foregroundStyle(category == cat ? cat.color : .primary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(category == cat ? cat.color : Color.clear, lineWidth: 1.5)
                                )
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            DatePicker("Tanggal", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .padding(12)
                .background(BagiTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text("Catatan (Opsional)")
                    .font(.subheadline)
                    .foregroundStyle(BagiTheme.muted)
                TextField("Tambah catatan...", text: $note)
                    .padding(12)
                    .background(BagiTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    
    }

    private func quickAmountButton(label: String, amount: Double) -> some View {
        Button(action: {
            let current = Double(amountText) ?? 0
            amountText = "\(Int(current + amount))"
        }) {
            Text(label)
                .font(.footnote)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(BagiTheme.primary.opacity(0.12))
                .foregroundStyle(BagiTheme.primary)
                .clipShape(Capsule())
        }
    }

}
