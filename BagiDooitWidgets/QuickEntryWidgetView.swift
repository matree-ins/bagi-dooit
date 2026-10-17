// Widget dinonaktifkan sementara; akses cepat menggunakan Siri dan Shortcuts.
// import SwiftUI
// import WidgetKit
//
// struct QuickEntryWidgetView: View {
//     var body: some View {
//         VStack(alignment: .leading, spacing: 12) {
//             Text("Bagi Dooit")
//                 .font(.headline)
//                 .foregroundStyle(Color("BagiInk"))
//             HStack(spacing: 12) {
//                 entryLink("Foto Struk", symbol: "camera.viewfinder", destination: "bagidooit://scan")
//                 entryLink("Catat lewat suara", symbol: "mic.fill", destination: "bagidooit://voice")
//             }
//         }
//     }
//
//     private func entryLink(_ title: String, symbol: String, destination: String) -> some View {
//         Link(destination: URL(string: destination)!) {
//             VStack(alignment: .leading, spacing: 8) {
//                 Image(systemName: symbol)
//                     .font(.title2)
//                 Text(title)
//                     .font(.subheadline.weight(.semibold))
//                     .fixedSize(horizontal: false, vertical: true)
//             }
//             .foregroundStyle(Color("BagiPrimary"))
//             .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
//             .padding(12)
//             .background(Color("BagiSoft"), in: .rect(cornerRadius: 16))
//             .contentShape(.rect)
//         }
//         .accessibilityLabel(title)
//     }
// }
//
// #Preview(as: .systemMedium) {
//     BagiDooitWidgets()
// } timeline: {
//     QuickEntryTimeline(date: .now)
// }
