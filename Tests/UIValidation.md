# UI validation

Validated on an isolated iPhone 18 Pro simulator running iOS 27. The QA app uses a separate bundle and seeded demo data; the original project signing and bundle settings were preserved.

- Two native XCTest UI checks passed: open a recent split bill and tap Selesai to return to Beranda; open Riwayat and verify Daftar Transaksi and input-source badges are absent.
- Ten screenshots cover Beranda, Tips Hemat, scan entry, split participant selection, and Riwayat at accessibility text size in light/dark appearances.
- 75 model/storage regression checks passed via `bash Tests/run-regressions.sh`.
- 14 foreground/surface/action contrast pairs passed the 4.5:1 minimum in both modes via `python3 Tests/check-theme-contrast.py`.
- Production iOS Simulator build succeeded.

Current-run QA source, screenshot gallery and XCTest result bundle are under /tmp/bagi-ui. UI tests were built in that isolated project; no temporary test target was added to the production Xcode project. Actual camera/speech and physical-device Apple Intelligence behavior were outside this UI validation.
