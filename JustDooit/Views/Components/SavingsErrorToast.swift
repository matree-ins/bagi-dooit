import SwiftUI

struct SavingsErrorToast: View {
    let notice: SavingsErrorNotice
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                Text(notice.message).font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Tutup pesan", systemImage: "xmark", action: onDismiss)
                    .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
            }
            if notice.canRetry {
                Button("Coba lagi", action: onRetry).font(.subheadline.bold()).frame(minHeight: 44)
            }
        }
        .padding()
        .foregroundStyle(BagiTheme.ink)
        .background(BagiTheme.surface, in: .rect(cornerRadius: BagiTheme.radius))
        .overlay(RoundedRectangle(cornerRadius: BagiTheme.radius).stroke(BagiTheme.soft))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        .padding(.horizontal)
        .task(id: notice.id) {
            AccessibilityNotification.Announcement(notice.message).post()
            do { try await Task.sleep(for: .seconds(9)) } catch { return }
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }
}
