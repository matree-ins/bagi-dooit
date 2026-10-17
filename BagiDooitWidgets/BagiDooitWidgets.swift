import SwiftUI
import WidgetKit

@main
struct BagiDooitWidgets: Widget {
    let kind = "BagiDooitQuickEntry"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickEntryProvider()) { _ in
            QuickEntryWidgetView()
                .widgetURL(URL(string: "bagidooit://scan"))
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Bagi Dooit")
        .description("Buka pemindai struk Bagi Dooit.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
