import SwiftUI

struct SavingsAISection: View {
    let service: SavingsAIService
    let advice: FinancialBehaviorAdvice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Kebiasaan kecil, lebih hemat", systemImage: "lightbulb.fill")
                .font(.headline)
            if service.isGenerating {
                ProgressView("Menyiapkan saran…").font(.footnote)
            }
            if let suggestion = service.suggestion {
                Text(suggestion.summary).font(.subheadline)
                actions(suggestion.actions)
            } else if !service.isGenerating {
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
