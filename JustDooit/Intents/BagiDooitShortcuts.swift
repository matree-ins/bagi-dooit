import AppIntents

// Siri only matches phrases in the device's Siri language, and Siri does not support
// Indonesian yet. English phrases are the ones that actually trigger these intents.
struct BagiDooitShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .teal }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateSplitBillIntent(),
            phrases: [
                "Create a split bill in \(.applicationName)",
                "Split a bill with \(.applicationName)",
                "Split a bill in \(.applicationName)",
                "Record a split bill in \(.applicationName)",
                "New split bill in \(.applicationName)",
                "Buat split bill di \(.applicationName)",
                "Catat split bill di \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Buat Split Bill", table: "Localizable"),
            systemImageName: "person.2.fill"
        )
        AppShortcut(
            intent: ScanReceiptIntent(),
            phrases: [
                "Scan a receipt in \(.applicationName)",
                "Foto struk di \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Foto Struk", table: "Localizable"),
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: VoiceExpenseIntent(),
            phrases: [
                "Open voice input in \(.applicationName)",
                "Buka input suara di \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Buka Input Suara", table: "Localizable"),
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: RecordExpenseIntent(),
            phrases: [
                "Record an expense in \(.applicationName)",
                "Add an expense in \(.applicationName)",
                "Catat pengeluaran di \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Catat Pengeluaran", table: "Localizable"),
            systemImageName: "square.and.pencil"
        )
    }
}
