import AppIntents

struct BagiDooitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateSplitBillIntent(),
            phrases: [
                "Buat split bill di \(.applicationName)",
                "Bagi tagihan di \(.applicationName)",
                "Catat split bill di \(.applicationName)",
                "Create a split bill in \(.applicationName)",
                "Split a bill with \(.applicationName)"
            ],
            shortTitle: "Buat Split Bill",
            systemImageName: "person.2.fill"
        )
        AppShortcut(
            intent: ScanReceiptIntent(),
            phrases: [
                "Foto struk di \(.applicationName)",
                "Scan a receipt in \(.applicationName)"
            ],
            shortTitle: "Foto Struk",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: VoiceExpenseIntent(),
            phrases: [
                "Buka input suara di \(.applicationName)",
                "Open voice input in \(.applicationName)"
            ],
            shortTitle: "Buka Input Suara",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: RecordExpenseIntent(),
            phrases: [
                "Catat pengeluaran di \(.applicationName)",
                "Record an expense in \(.applicationName)"
            ],
            shortTitle: "Catat Pengeluaran",
            systemImageName: "square.and.pencil"
        )
    }
}
