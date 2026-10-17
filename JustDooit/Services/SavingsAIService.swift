import Foundation
import Observation

@Observable
@MainActor
final class SavingsAIService {
    private(set) var suggestion: SavingsSuggestion?
    private(set) var isGenerating = false
    private(set) var errorNotice: SavingsErrorNotice?
    @ObservationIgnored private let provider: any SavingsSuggestionProviding
    @ObservationIgnored private let timeoutNanoseconds: UInt64
    @ObservationIgnored private let debounceNanoseconds: UInt64
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var currentKey: SavingsAdviceKey?
    @ObservationIgnored private var attemptedAt: Date?
    @ObservationIgnored private var availabilityAtAttempt: String?

    init(provider: any SavingsSuggestionProviding, timeoutNanoseconds: UInt64 = 30_000_000_000,
         debounceNanoseconds: UInt64 = 350_000_000) {
        self.provider = provider
        self.timeoutNanoseconds = timeoutNanoseconds
        self.debounceNanoseconds = debounceNanoseconds
    }

    var notice: String? { errorNotice?.message }

    func dismissError() { errorNotice = nil }

    func invalidate() {
        task?.cancel()
        watchdog?.cancel()
        task = nil
        watchdog = nil
        requestID = UUID()
        currentKey = nil
        attemptedAt = nil
        suggestion = nil
        errorNotice = nil
        isGenerating = false
    }

    func pause() {
        // Completed suggestions remain cached across tab switches and short background visits.
        if isGenerating { invalidate() }
        dismissError()
    }

    func refresh(for advice: FinancialBehaviorAdvice, force: Bool = false, now: Date = Date()) {
        guard advice.threeDayTotal.isFinite, advice.threeDayTotal > 0,
              advice.safeDailyLimit.isFinite, advice.safeDailyLimit > 0 else {
            invalidate()
            return // Empty data is a normal empty state, not an error.
        }
        let key = SavingsAdviceKey(advice, now: now)
        let issue = provider.availabilityIssue
        if !force, key == currentKey, issue == availabilityAtAttempt,
           suggestion != nil || isGenerating || now.timeIntervalSince(attemptedAt ?? .distantPast) < 60 {
            return
        }
        invalidate()
        currentKey = key
        attemptedAt = now
        availabilityAtAttempt = issue
        if let issue {
            errorNotice = SavingsErrorNotice(message: issue + " Saran bawaan tetap ditampilkan.", canRetry: provider.availabilityCanRetry)
            return
        }
        let id = requestID
        isGenerating = true
        task = Task { [weak self, provider, debounceNanoseconds] in
            do {
                try await Task.sleep(nanoseconds: debounceNanoseconds)
                try Task.checkCancellation()
                let generated = try await provider.generate(for: advice)
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                guard generated.isValid else {
                    self.finish()
                    self.errorNotice = SavingsErrorNotice(message: "Saran AI belum terbaca dengan baik. Saran bawaan tetap ditampilkan.")
                    return
                }
                self.finish()
                self.suggestion = generated
            } catch {
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                self.finish()
                guard !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
                self.errorNotice = SavingsAIErrorMessage.notice(for: error)
            }
        }
        watchdog = Task { [weak self, timeoutNanoseconds] in
            do { try await Task.sleep(nanoseconds: timeoutNanoseconds) } catch { return }
            guard let self, self.requestID == id, self.isGenerating else { return }
            self.task?.cancel()
            self.task = nil
            self.requestID = UUID()
            self.isGenerating = false
            self.errorNotice = SavingsErrorNotice(message: "Menyiapkan saran terlalu lama. Saran bawaan tetap ditampilkan; kamu bisa mencoba lagi.")
            self.watchdog = nil
        }
    }

    func generate(for advice: FinancialBehaviorAdvice) { refresh(for: advice, force: true) }

    private func finish() {
        watchdog?.cancel()
        watchdog = nil
        task = nil
        isGenerating = false
    }
}
