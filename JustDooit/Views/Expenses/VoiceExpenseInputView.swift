import SwiftUI
import PhotosUI

struct VoiceExpenseInputView: View {
    @ObservedObject var speechService: SpeechRecognitionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Ceritakan pengeluaranmu")
                    .font(.headline)
                Text("Contoh: \"Makan siang soto tiga puluh lima ribu\" atau \"Isi bensin lima puluh ribu\"")
                    .font(.footnote)
                    .foregroundStyle(BagiTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            if let error = speechService.errorMessage {
                InputErrorNotice(message: error, showSettings: true)
            }

            // Mic Record Button
            ZStack {
                Circle()
                    .fill(speechService.isRecording ? Color.red.opacity(0.2) : BagiTheme.primary.opacity(0.1))
                    .frame(width: 110, height: 110)
                    .scaleEffect(speechService.isRecording && !reduceMotion ? 1.15 : 1.0)
                    .animation(speechService.isRecording && !reduceMotion ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : nil, value: speechService.isRecording)

                Button(action: toggleRecording) {
                    Label(speechService.isRecording ? "Selesai merekam" : "Mulai merekam", systemImage: speechService.isRecording ? "stop.fill" : "mic.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(speechService.isRecording ? Color.red : BagiTheme.primary)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .disabled(speechService.isRequestingPermission)
            }

            Text(speechService.isRecording ? "Mendengarkan... Tekan tombol untuk selesai" : "Tekan mikrofon untuk mulai berbicara")
                .font(.footnote)
                .foregroundStyle(speechService.isRecording ? .red : .secondary)

            // Transcribed Result Card
            if !speechService.transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hasil suara")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundStyle(BagiTheme.muted)

                    Text("\"\(speechService.transcribedText)\"")
                        .font(.body)
                        .italic()

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Judul")
                                .font(.footnote)
                                .foregroundStyle(BagiTheme.muted)
                            Text(speechService.detectedTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Nominal")
                                .font(.footnote)
                                .foregroundStyle(BagiTheme.muted)
                            Text(CurrencyFormatter.format(speechService.detectedAmount))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(BagiTheme.primary)
                        }
                    }

                    HStack {
                        Text("Kategori Otomatis:")
                            .font(.footnote)
                            .foregroundStyle(BagiTheme.muted)
                        Label(speechService.detectedCategory.rawValue, systemImage: speechService.detectedCategory.icon)
                            .font(.footnote)
                            .foregroundStyle(speechService.detectedCategory.color)
                    }
                }
                .padding()
                .background(BagiTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: BagiTheme.radius))
            }

            // Demo Voice Simulator Presets (Ideal for Hackathon Judges)
            VStack(alignment: .leading, spacing: 10) {
                Text("Coba contoh suara")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(BagiTheme.muted)

                VStack(spacing: 8) {
                    demoVoiceButton(text: "Beli Kopi Kenangan 28 ribu")
                    demoVoiceButton(text: "Isi Bensin Pertamax 50 ribu")
                    demoVoiceButton(text: "Makan Nasi Padang 35 ribu")
                    demoVoiceButton(text: "Bayar Tagihan Wifi 250 ribu")
                }
            }
            .padding(.top, 8)
        }
    
    }

    private func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task { await speechService.requestAndStartRecording() }
        }
    }

    private func demoVoiceButton(text: String) -> some View {
        Button(action: {
            speechService.simulateVoiceInput(text)
        }) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(BagiTheme.primary)
                Text("\"\(text)\"")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(BagiTheme.muted)
            }
            .padding(10)
            .background(BagiTheme.soft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

}
