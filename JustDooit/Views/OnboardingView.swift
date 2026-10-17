//
//  OnboardingView.swift
//  JustDooit
//

import SwiftUI

struct OnboardingView: View {
    var onGetStarted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Text Section
            headerSection
                .padding(.top, 40)
                .padding(.horizontal, 24)

            Spacer()

            // Meal Illustration
            illustrationSection
                .frame(maxWidth: .infinity)

            Spacer()

            // Bottom CTA Button
            actionButton
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .bagiScreen()
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Makan bareng.")
                Text("Bayar sesuai porsi.")
            }
            .font(.largeTitle.bold())
            .foregroundStyle(BagiTheme.ink)

            Text("Foto atau ceritakan tagihanmu. Bagi sesuai pesanan.")
                .font(.body)
                .foregroundStyle(BagiTheme.muted)
                .lineSpacing(4)
        }
    }

    // MARK: - Illustration Section
    private var illustrationSection: some View {
        Image("OnboardMeal")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 320)
            .padding(.horizontal, 24)
            .accessibilityHidden(true)
    }

    // MARK: - Action Button
    private var actionButton: some View {
        Button(action: onGetStarted) {
            Text("Mulai Bagi Dooit")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .background(BagiTheme.action)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    OnboardingView(onGetStarted: {})
}
