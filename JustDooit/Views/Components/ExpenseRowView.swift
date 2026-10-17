import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon Badge
            Circle()
                .fill(expense.category.color.opacity(0.18))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: expense.category.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(expense.category.color)
                )

            // Title & Details
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(expense.date, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)

                    // Input Method Tag
                    HStack(spacing: 2) {
                        Image(systemName: expense.inputMethod.icon)
                        Text(expense.inputMethod.rawValue)
                    }
                    .font(.system(.footnote))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(BagiTheme.soft)
                    .foregroundStyle(BagiTheme.muted)
                    .clipShape(Capsule())
                }
            }

            Spacer()

            // Amount
            Text(CurrencyFormatter.format(expense.amount))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            // Delete Button
            Button(role: .destructive, action: onDelete) {
                Label("Hapus \(expense.title)", systemImage: "trash")
                    .labelStyle(.iconOnly)
                    .font(.body)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .padding(.leading, 4)
        }
        .padding(12)
        .background(BagiTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
    }
}
