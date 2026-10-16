import SwiftUI
import UIKit

struct SplitBillReceiptScannerView: View {
    var onImport: ([ScannedReceiptItem]) -> Void
    @StateObject private var scanner = ReceiptScannerService()

    var body: some View {
        VStack(spacing: 20) {
            Text("Gunakan contoh struk untuk menambahkan item.")
                .font(.footnote)
                .foregroundStyle(BagiTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { scanner.loadDemoReceipt() }) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Coba contoh struk")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            if let result = scanner.scanResult {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hasil OCR: \(result.merchantName)")
                        .font(.headline)

                    ForEach(result.items) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text(CurrencyFormatter.format(item.price))
                                .fontWeight(.medium)
                        }
                        .font(.footnote)
                    }

                    Button(action: {
                        onImport(result.items)
                    }) {
                        Text("Import \(result.items.count) Item ke Split Bill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(BagiTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(BagiTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top)
    }
}
