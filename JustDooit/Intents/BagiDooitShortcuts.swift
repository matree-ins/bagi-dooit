import AppIntents

struct BagiDooitShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .teal }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateSplitBillIntent(),
            phrases: [
                // Indonesian — di / ke / dengan / pakai (Siri sering dengar "ke", bukan "di")
                "Buat split bill di \(.applicationName)",
                "Buat split bill ke \(.applicationName)",
                "Catat split bill di \(.applicationName)",
                "Catat split bill ke \(.applicationName)",
                "Bagi tagihan di \(.applicationName)",
                "Bagi tagihan ke \(.applicationName)",
                "Split bill di \(.applicationName)",
                "Split bill ke \(.applicationName)",
                "Pakai \(.applicationName) buat split bill",
                "Pakai \(.applicationName) catat split bill",
                "Dengan \(.applicationName) buat split bill",
                // English forms Apple matches most reliably
                "Create a split bill in \(.applicationName)",
                "Create a split bill with \(.applicationName)",
                "Split a bill with \(.applicationName)",
                "Split a bill in \(.applicationName)",
                "Record a split bill in \(.applicationName)",
                "\(.applicationName) create a split bill",
                "\(.applicationName) split a bill"
            ],
            shortTitle: "Buat Split Bill",
            systemImageName: "person.2.fill"
        )
        AppShortcut(
            intent: ScanReceiptIntent(),
            phrases: [
                "Foto struk di \(.applicationName)",
                "Foto struk ke \(.applicationName)",
                "Scan a receipt in \(.applicationName)",
                "\(.applicationName) scan a receipt"
            ],
            shortTitle: "Foto Struk",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: VoiceExpenseIntent(),
            phrases: [
                "Buka input suara di \(.applicationName)",
                "Buka input suara ke \(.applicationName)",
                "Open voice input in \(.applicationName)",
                "\(.applicationName) open voice input"
            ],
            shortTitle: "Buka Input Suara",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: RecordExpenseIntent(),
            phrases: [
                "Catat pengeluaran di \(.applicationName)",
                "Catat pengeluaran ke \(.applicationName)",
                "Record an expense in \(.applicationName)",
                "\(.applicationName) record an expense"
            ],
            shortTitle: "Catat Pengeluaran",
            systemImageName: "square.and.pencil"
        )
    }
}
