import SwiftUI
import UIKit
import PhotosUI

struct SplitBillReceiptScannerView: View {
    var onImport: ([ScannedReceiptItem]) -> Void
    @StateObject private var scanner = ReceiptScannerService()

    @State private var showCameraPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Pindai Struk Restoran")
                        .font(.headline)
                    Text("Pindai atau pilih foto struk untuk membaca daftar menu makanan secara otomatis.")
                        .font(.footnote)
                        .foregroundStyle(BagiTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 8)

                if let error = scanner.errorMessage {
                    InputErrorNotice(message: error)
                        .padding(.horizontal)
                }

                // Action Buttons
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

                    Button(action: { scanner.loadDemoReceipt() }) {
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
                .padding(.horizontal)

                if scanner.isScanning {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Membaca menu struk…")
                            .font(.footnote)
                            .foregroundStyle(BagiTheme.muted)
                    }
                    .padding()
                }

                // Scanned Result Preview
                if let result = scanner.scanResult {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Merchant")
                                    .font(.caption)
                                    .foregroundStyle(BagiTheme.muted)
                                Text(result.merchantName)
                                    .font(.headline)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Total Struk")
                                    .font(.caption)
                                    .foregroundStyle(BagiTheme.muted)
                                Text(CurrencyFormatter.format(result.totalAmount))
                                    .font(.headline)
                                    .foregroundStyle(BagiTheme.primary)
                            }
                        }

                        Divider()

                        if result.items.isEmpty {
                            Text("Tidak ada menu yang terdeteksi.")
                                .font(.subheadline)
                                .foregroundStyle(BagiTheme.muted)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            Text("Menu Terdeteksi (\(result.items.count)):")
                                .font(.footnote)
                                .fontWeight(.bold)
                                .foregroundStyle(BagiTheme.muted)

                            VStack(spacing: 8) {
                                ForEach(result.items) { item in
                                    HStack {
                                        Text(item.name)
                                            .font(.footnote)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(CurrencyFormatter.format(item.price))
                                            .font(.footnote)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }

                            Button(action: {
                                onImport(result.items)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Import \(result.items.count) Menu ke Split Bill")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(BagiTheme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    .background(BagiTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
                    .overlay(
                        RoundedRectangle(cornerRadius: BagiTheme.radius)
                            .stroke(BagiTheme.primary.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }

                Spacer(minLength: 30)
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPickerView(sourceType: .camera) { image in
                scanner.processImage(image)
            }
        }
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else { return }
            do {
                guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    scanner.reportImageLoadingError()
                    return
                }
                guard !Task.isCancelled else { return }
                scanner.processImage(image)
            } catch {
                guard !Task.isCancelled else { return }
                scanner.reportImageLoadingError()
            }
        }
    }
}
