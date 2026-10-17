//
//  JustDooitApp.swift
//  JustDooit
//
//  Created by Training-61 on 16/10/26.
//

import AppIntents
import SwiftUI

@main
struct BagiDooitApp: App {
    init() {
        // Donate/refresh Siri phrases after install or phrase list changes.
        BagiDooitShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(BagiTheme.primary)
        }
    }
}
