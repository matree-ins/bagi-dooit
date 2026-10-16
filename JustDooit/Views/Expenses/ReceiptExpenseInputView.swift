import SwiftUI
import PhotosUI

struct ReceiptExpenseInputView: View {
    @ObservedObject var scannerService: ReceiptScannerService
    @Binding var showCameraPicker: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Scan struk")
                    .font(.headline)
                Text("Foto struk untuk membaca item dan totalnya.")
                    .font(.footnote)
                    .foregroundStyle(BagiTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Scan Action Buttons
            HStack(spacing: 12) {
                Button(action: { showCameraPicker = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Kamera")
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(BagiTheme.primary.opacity(0.12))
                    .foregroundStyle(BagiTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                        Text("Galeri Foto")
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green.opacity(0.12))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: { scannerService.loadDemoReceipt() }) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.title2)
                        Text("Demo Struk")
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange.opacity(0.12))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if scannerService.isScanning {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Membaca struk…")
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                }
                .padding()
            }

            // Scanned Result Preview
            if let result = scannerService.scanResult {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Merchant / Toko")
                                .font(.footnote)
                                .foregroundStyle(BagiTheme.muted)
                            Text(result.merchantName)
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Total Terdeteksi")
                                .font(.footnote)
                                .foregroundStyle(BagiTheme.muted)
                            Text(CurrencyFormatter.format(result.totalAmount))
                                .font(.headline)
                                .foregroundStyle(BagiTheme.primary)
                        }
                    }

                    Divider()

                    if !result.items.isEmpty {
                        Text("Item Terdeteksi (\(result.items.count)):")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundStyle(BagiTheme.muted)

                        ForEach(result.items) { item in
                            HStack {
                                Text(item.name)
                                    .font(.footnote)
                                Spacer()
                                Text(CurrencyFormatter.format(item.price))
                                    .font(.footnote)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                .padding()
                .background(BagiTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
                .overlay(
                    RoundedRectangle(cornerRadius: BagiTheme.radius)
                        .stroke(BagiTheme.primary.opacity(0.3), lineWidth: 1)
                )
            }
        }
    
    }

}
