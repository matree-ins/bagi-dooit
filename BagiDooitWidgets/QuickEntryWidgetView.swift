import SwiftUI
import WidgetKit

struct QuickEntryWidgetView: View {
    var body: some View {
        Link(destination: URL(string: "bagidooit://scan")!) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bagi Dooit")
                    .font(.headline)
                    .foregroundStyle(Color("BagiInk"))
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.largeTitle)
                    Text("Foto Struk")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color("BagiPrimary"))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(12)
                .background(Color("BagiSoft"), in: .rect(cornerRadius: 16))
            }
            .contentShape(.rect)
        }
        .accessibilityLabel("Foto Struk")
        .accessibilityHint("Membuka pemindai struk di Bagi Dooit")
    }
}

#Preview(as: .systemSmall) {
    BagiDooitWidgets()
} timeline: {
    QuickEntryTimeline(date: .now)
}
