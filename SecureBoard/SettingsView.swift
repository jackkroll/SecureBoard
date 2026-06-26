//
//  SettingsView.swift
//  SecureBoard
//

import AppKit
import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject private var manager: PasteboardMonitor
    @ObservedObject private var appController = AppController.shared
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if let onDismiss {
                HStack {
                    Text("Settings")
                        .font(.headline)
                    Spacer()
                    Button("Done", action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
            }

            Form {
                Section {
                    LabeledContent("Open SecureBoard") {
                        KeyboardShortcuts.Recorder(for: .globalOpen)
                    }
                } header: {
                    Text("Keybind")
                } footer: {
                    Text("Global shortcut to show or hide SecureBoard from anywhere.")
                }

                Section {
                    if appController.launchAtLoginNeedsApproval {
                        Button("Approve Start at Login in System Settings…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    } else {
                        Toggle("Start at Login", isOn: launchAtLoginBinding)
                    }
                    Button("Check for Updates…") {
                        appController.checkForUpdates()
                    }
                } header: {
                    Text("General")
                }

                Section {
                    Button("Rotate Encryption Key…", role: .destructive) {
                        manager.rotateKey()
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("Generates a new encryption key. Existing entries cannot be decrypted with the new key.")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 340)
        .onAppear {
            appController.refreshLaunchAtLoginStatus()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appController.isLaunchAtLoginEnabled },
            set: { newValue in
                if newValue != appController.isLaunchAtLoginEnabled {
                    appController.toggleLaunchAtLogin()
                }
            }
        )
    }
}
