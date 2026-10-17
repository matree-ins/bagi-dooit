import SwiftUI

struct SavingsAISection: View {
    let service: SavingsAIService
    let advice: FinancialBehaviorAdvice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Kebiasaan kecil, lebih hemat", systemImage: "lightbulb.fill")
                    .font(.headline)
                Spacer(minLength: 8)
                if service.isGenerating {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel("Memperbarui saran")
                }
            }
            if let suggestion = service.suggestion {
                Text(suggestion.summary).font(.subheadline)
                actions(suggestion.actions)
            } else {
                actions(SavingsFallback.actions(for: advice))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actions(_ values: [String]) -> some View {
        ForEach(values, id: \.self) { action in
            Label(action, systemImage: "checkmark.circle")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
