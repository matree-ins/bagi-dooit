import SwiftUI

struct InputErrorNotice: View {
    let message: String
    var showSettings = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if showSettings {
                Button("Buka Pengaturan", systemImage: "gearshape") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .frame(minHeight: 44)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BagiTheme.soft, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }
}
