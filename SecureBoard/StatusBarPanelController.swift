//
//  StatusBarPanelController.swift
//  SecureBoard
//

import AppKit
import Combine
import SwiftData
import SwiftUI

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class PanelPresentation: ObservableObject {
    @Published private(set) var isShown = false

    func present() {
        if isShown {
            isShown = false
        }

        withAnimation(.easeOut(duration: 0.18)) {
            isShown = true
        }
    }

    func dismissImmediately() {
        isShown = false
    }

    func dismissAnimated(completion: @escaping @MainActor () -> Void) {
        withAnimation(.easeIn(duration: 0.14)) {
            isShown = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            completion()
        }
    }
}

private struct PanelContainerView: View {
    @ObservedObject var presentation: PanelPresentation
    let pasteboardMonitor: PasteboardMonitor
    let modelContainer: ModelContainer
    let panelSize: CGSize

    var body: some View {
        ContentView()
            .environmentObject(pasteboardMonitor)
            .modelContainer(modelContainer)
            .frame(width: panelSize.width, height: panelSize.height)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(y: presentation.isShown ? 1 : 0.01, anchor: .top)
            .opacity(presentation.isShown ? 1 : 0)
    }
}

@MainActor
final class StatusBarPanelController: NSObject, NSWindowDelegate {
    private let pasteboardMonitor: PasteboardMonitor
    private let modelContainer: ModelContainer
    private let presentation = PanelPresentation()

    private var statusItem: NSStatusItem?
    private var panel: KeyablePanel?
    private var hostingController: NSHostingController<PanelContainerView>?
    private let panelSize = NSSize(width: 380, height: 540)
    private var isStarted = false
    private var isPanelOpen = false
    private var suppressResignKeyHide = false
    private var hideTask: Task<Void, Never>?

    private static var shared: StatusBarPanelController?

    static func install(
        pasteboardMonitor: PasteboardMonitor,
        modelContainer: ModelContainer
    ) -> StatusBarPanelController {
        if let shared {
            return shared
        }

        let controller = StatusBarPanelController(
            pasteboardMonitor: pasteboardMonitor,
            modelContainer: modelContainer
        )
        shared = controller
        return controller
    }

    private init(pasteboardMonitor: PasteboardMonitor, modelContainer: ModelContainer) {
        self.pasteboardMonitor = pasteboardMonitor
        self.modelContainer = modelContainer
        super.init()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        configureStatusItem()
        configurePanel()
    }

    func togglePanel() {
        guard isStarted else { return }

        if isPanelOpen {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "SecureBoard")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp])
        }

        statusItem = item
    }

    private func configurePanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

        self.panel = panel
    }

    private func installPanelContentIfNeeded() {
        guard let panel, hostingController == nil else { return }

        let rootView = PanelContainerView(
            presentation: presentation,
            pasteboardMonitor: pasteboardMonitor,
            modelContainer: modelContainer,
            panelSize: panelSize
        )

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.frame = NSRect(origin: .zero, size: panelSize)
        hostingController.view.autoresizingMask = [.width, .height]

        panel.contentView = hostingController.view
        self.hostingController = hostingController
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showContextMenu(for: sender)
            return
        }

        suppressResignKeyHide = true
        if isPanelOpen {
            hidePanel()
        } else {
            showPanel()
        }

        DispatchQueue.main.async { [weak self] in
            self?.suppressResignKeyHide = false
        }
    }

    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit SecureBoard",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )

        menu.items.forEach { $0.target = self }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openSettings() {
        if !isPanelOpen {
            showPanel()
        }
        NotificationCenter.default.post(name: .presentSettings, object: nil)
    }

    @objc private func quitApplication() {
        AppController.shared.quit()
    }

    private func showPanel() {
        guard let panel, let button = statusItem?.button else { return }

        installPanelContentIfNeeded()

        hideTask?.cancel()
        hideTask = nil
        isPanelOpen = true

        positionPanel(below: button)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        presentation.present()
    }

    private func hidePanel() {
        guard isPanelOpen, let panel else { return }

        NotificationCenter.default.post(name: .dismissSettings, object: nil)
        isPanelOpen = false
        hideTask?.cancel()

        hideTask = Task { @MainActor in
            presentation.dismissAnimated {
                guard !self.isPanelOpen else { return }
                panel.orderOut(nil)
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.suppressResignKeyHide, self.isPanelOpen else { return }
            self.hidePanel()
        }
    }

    private func positionPanel(below button: NSStatusBarButton) {
        guard let panel, let screen = button.window?.screen ?? NSScreen.main else { return }

        let buttonFrame = button.convert(button.bounds, to: nil)
        guard let window = button.window else { return }

        let screenRect = window.convertToScreen(buttonFrame)
        let x = min(
            max(screenRect.midX - (panelSize.width / 2), screen.visibleFrame.minX + 8),
            screen.visibleFrame.maxX - panelSize.width - 8
        )
        let y = screenRect.minY - panelSize.height - 4

        panel.setFrame(
            NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height),
            display: false
        )
    }
}
