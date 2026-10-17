import SwiftUI

struct ExpenseRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let expense: Expense
    let onDelete: () -> Void

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
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
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(expense.date, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)


                }
            }

            if !dynamicTypeSize.isAccessibilitySize { Spacer() }

            // Amount
            Text(CurrencyFormatter.format(expense.amount))
                .font(.subheadline.bold()).monospacedDigit()
                .foregroundStyle(BagiTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

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
