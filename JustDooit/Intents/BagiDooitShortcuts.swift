import AppIntents

struct BagiDooitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ScanReceiptIntent(), phrases: ["Scan a receipt in \(.applicationName)"], shortTitle: "Foto Struk", systemImageName: "camera.viewfinder")
        AppShortcut(intent: VoiceExpenseIntent(), phrases: ["Record by voice in \(.applicationName)"], shortTitle: "Catat lewat Suara", systemImageName: "mic.fill")
        AppShortcut(intent: RecordExpenseIntent(), phrases: ["Record an expense in \(.applicationName)"], shortTitle: "Catat Pengeluaran", systemImageName: "square.and.pencil")
    }
}
