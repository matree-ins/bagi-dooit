import SwiftUI
import PhotosUI

struct VoiceExpenseInputView: View {
    @ObservedObject var speechService: SpeechRecognitionService
    @Binding var title: String
    @Binding var amountText: String
    @Binding var category: ExpenseCategory

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

            // Mic Record Button
            ZStack {
                Circle()
                    .fill(speechService.isRecording ? Color.red.opacity(0.2) : BagiTheme.primary.opacity(0.1))
                    .frame(width: 110, height: 110)
                    .scaleEffect(speechService.isRecording ? 1.15 : 1.0)
                    .animation(speechService.isRecording ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: speechService.isRecording)

                Button(action: {
                    if speechService.isRecording {
                        speechService.stopRecording()
                        applySpeechResult()
                    } else {
                        speechService.requestAuthorization { granted in
                            if granted {
                                speechService.startRecording()
                            }
                        }
                    }
                }) {
                    Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(speechService.isRecording ? Color.red : BagiTheme.primary)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
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

    private func applySpeechResult() {
        if !speechService.detectedTitle.isEmpty {
            self.title = speechService.detectedTitle
        }
        if speechService.detectedAmount > 0 {
            self.amountText = "\(Int(speechService.detectedAmount))"
        }
        self.category = speechService.detectedCategory
    }

    private func demoVoiceButton(text: String) -> some View {
        Button(action: {
            speechService.simulateVoiceInput(text)
            applySpeechResult()
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
