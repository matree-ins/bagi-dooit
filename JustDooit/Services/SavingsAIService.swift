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
    @ObservationIgnored private var notifiedKey: SavingsAdviceKey?
    @ObservationIgnored private var notifiedMessage: String?

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
        if isGenerating {
            let retained = suggestion
            let retainedKey = currentKey
            let retainedAttempt = attemptedAt
            let retainedAvailability = availabilityAtAttempt
            invalidate()
            if retained != nil {
                suggestion = retained
                currentKey = retainedKey
                attemptedAt = retainedAttempt
                availabilityAtAttempt = retainedAvailability
            }
        }
        dismissError()
    }

    func refresh(for advice: FinancialBehaviorAdvice, force: Bool = false, now: Date = Date()) {
        guard advice.totalAmount.isFinite, advice.totalAmount > 0,
              advice.safeDailyLimit.isFinite, advice.safeDailyLimit > 0 else {
            invalidate()
            return // Empty data is a normal empty state, not an error.
        }
        let key = SavingsAdviceKey(advice, now: now)
        let issue = provider.availabilityIssue
        if !force, key == currentKey, issue == availabilityAtAttempt,
           suggestion != nil || isGenerating || (issue != nil && !provider.availabilityCanRetry) || now.timeIntervalSince(attemptedAt ?? .distantPast) < 60 {
            return
        }
        let retained = key == currentKey ? suggestion : nil
        invalidate()
        suggestion = retained
        currentKey = key
        attemptedAt = now
        availabilityAtAttempt = issue
        if let issue {
            publish(SavingsErrorNotice(message: issue + " Saran yang tersedia tetap ditampilkan.", canRetry: provider.availabilityCanRetry), force: force)
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
                    self.publish(SavingsErrorNotice(message: "Saran belum berhasil diperbarui. Saran yang tersedia tetap ditampilkan."), force: force)
                    return
                }
                self.finish()
                self.suggestion = generated
            } catch {
                guard let self, !Task.isCancelled, self.requestID == id else { return }
                self.finish()
                guard !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
                self.publish(SavingsAIErrorMessage.notice(for: error), force: force)
            }
        }
        watchdog = Task { [weak self, timeoutNanoseconds] in
            do { try await Task.sleep(nanoseconds: timeoutNanoseconds) } catch { return }
            guard let self, self.requestID == id, self.isGenerating else { return }
            self.task?.cancel()
            self.task = nil
            self.requestID = UUID()
            self.isGenerating = false
            self.publish(SavingsErrorNotice(message: "Memperbarui saran terlalu lama. Saran yang tersedia tetap ditampilkan; kamu bisa mencoba lagi."), force: force)
            self.watchdog = nil
        }
    }

    func generate(for advice: FinancialBehaviorAdvice) { refresh(for: advice, force: true) }

    private func publish(_ notice: SavingsErrorNotice, force: Bool) {
        guard force || notifiedKey != currentKey || notifiedMessage != notice.message else { return }
        notifiedKey = currentKey
        notifiedMessage = notice.message
        errorNotice = notice
    }

    private func finish() {
        watchdog?.cancel()
        watchdog = nil
        task = nil
        isGenerating = false
    }
}
