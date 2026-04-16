//
//  NeuroRuneApp.swift
//  NeuroRune
//
//  Created by tykim
//

import SwiftUI
import Dependencies

@main
struct NeuroRuneApp: App {
    init() {
        @Dependency(\.audioRecorder) var audioRecorder
        audioRecorder.cleanupOrphanedFiles()
        SpeechSettings.removeLegacyDefaults(from: .standard)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .background(Color("DarkNavy"))
        }
    }
}
