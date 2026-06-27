//
//  SecureBoardApp.swift
//  SecureBoard
//
//  Created by Jack Kroll on 6/8/26.
//

import SwiftUI
import KeyboardShortcuts
import Sparkle
import Combine

// This view model class publishes when new updates can be checked by the user
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    
    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

// This is the view for the Check for Updates menu item
// Note this intermediate view is necessary for the disabled state on the menu item to work properly before Monterey.
// See https://stackoverflow.com/questions/68553092/menu-not-updating-swiftui-bug for more info
struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    
    init(updater: SPUUpdater) {
        self.updater = updater
        
        // Create our view model for our CheckForUpdatesView
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

@main
struct SecureBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppBootstrap.makeAppState()

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState.pasteboardMonitor)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: AppController.shared.updater)
            }
        }
    }
}

extension KeyboardShortcuts.Name {
    static let globalOpen = Self("globalOpen", initial: .init(.v, modifiers: [.command, .shift]))
}
