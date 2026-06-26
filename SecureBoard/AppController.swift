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

    private var updaterController: SPUStandardUpdaterController?

    private init() {}

    func configure() {
        guard updaterController == nil else { return }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        refreshLaunchAtLoginStatus()
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
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
