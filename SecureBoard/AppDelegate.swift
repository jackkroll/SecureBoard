//
//  AppDelegate.swift
//  SecureBoard
//

import AppKit
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppBootstrap.start()
        AppController.shared.configure()

        KeyboardShortcuts.onKeyDown(for: .globalOpen) {
            NotificationCenter.default.post(name: .toggleMainPanel, object: nil)
        }
    }
}
