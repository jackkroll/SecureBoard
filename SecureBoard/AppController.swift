//
//  AppController.swift
//  SecureBoard
//

import AppKit
import Combine
import Sparkle

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    @Published private(set) var isLaunchAtLoginEnabled = false
    @Published private(set) var launchAtLoginNeedsApproval = false

    private let updaterController: SPUStandardUpdaterController

    var updater: SPUUpdater {
        updaterController.updater
    }

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func configure() {
        refreshLaunchAtLoginStatus()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func toggleLaunchAtLogin() {
        let targetState = !isLaunchAtLoginEnabled
        _ = LaunchAtLoginManager.setEnabled(targetState)
        refreshLaunchAtLoginStatus()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func refreshLaunchAtLoginStatus() {
        isLaunchAtLoginEnabled = LaunchAtLoginManager.isEnabled
        launchAtLoginNeedsApproval = LaunchAtLoginManager.needsApproval
    }

    var launchAtLoginButtonTitle: String {
        if launchAtLoginNeedsApproval {
            return "Approve in System Settings…"
        }
        return isLaunchAtLoginEnabled ? "Disable Start at Login" : "Start at Login"
    }
}
