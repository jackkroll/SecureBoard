//
//  SecureBoardApp.swift
//  SecureBoard
//
//  Created by Jack Kroll on 6/8/26.
//

import SwiftUI
import SwiftData

@main
struct SecureBoardApp: App {
    private let sharedModelContainer: ModelContainer
    @StateObject private var pasteboardMonitor: PasteboardMonitor

    init() {
        let container = Self.makeModelContainer()
        sharedModelContainer = container
        _pasteboardMonitor = StateObject(wrappedValue: PasteboardMonitor(container: container))
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            PasteboardItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pasteboardMonitor)
        }
        .modelContainer(sharedModelContainer)
    }
}
