import SwiftUI
import WidgetKit

@main
struct BagiDooitWidgets: Widget {
    let kind = "BagiDooitQuickEntry"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickEntryProvider()) { _ in
            QuickEntryWidgetView()
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Bagi Dooit")
        .description("Foto struk atau catat lewat suara.")
        .supportedFamilies([.systemMedium])
    }
}
