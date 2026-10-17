# Automatic spending suggestions

Suggestions generate automatically after onboarding and when expense or budget data changes. Generation uses Foundation Models locally and displays the original supported language directly, without a translation step, language downloads or translation permission prompts.

The suggestions remain inside Lihat rincian under Kebiasaan kecil, lebih hemat. Loading is shown while generating; model failures use a global toast with friendly Indonesian text and an appropriate retry action. Data-aware fallback tips remain labelled Saran bawaan. Totals and budget status are deterministic.

Run `bash Tests/run-regressions.sh` for model/state tests, including direct English display, budget changes, stale output, unavailable models, cancellation, network errors, timeout, caching and threshold boundaries. Physical-device airplane-mode and accessibility validation remain separate.
