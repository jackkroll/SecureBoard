//
//  AppState.swift
//  SecureBoard
//

import Combine
import Foundation
import SwiftData

@MainActor
enum AppBootstrap {
    private static var cachedAppState: AppState?

    static func makeAppState() -> AppState {
        if let cachedAppState {
            return cachedAppState
        }

        let container = makeModelContainer()
        let pasteboardMonitor = PasteboardMonitor(container: container)
        let appState = AppState(pasteboardMonitor: pasteboardMonitor, modelContainer: container)
        cachedAppState = appState
        return appState
    }

    static func start() {
        makeAppState().start()
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
}

@MainActor
final class AppState: ObservableObject {
    let pasteboardMonitor: PasteboardMonitor
    private let panelController: StatusBarPanelController

    private var togglePanelCancellable: AnyCancellable?

    fileprivate init(pasteboardMonitor: PasteboardMonitor, modelContainer: ModelContainer) {
        self.pasteboardMonitor = pasteboardMonitor
        panelController = StatusBarPanelController.install(
            pasteboardMonitor: pasteboardMonitor,
            modelContainer: modelContainer
        )

        togglePanelCancellable = NotificationCenter.default.publisher(for: .toggleMainPanel)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.panelController.togglePanel()
            }
    }

    func start() {
        panelController.start()
    }

    func togglePanel() {
        panelController.togglePanel()
    }
}

extension Notification.Name {
    static let toggleMainPanel = Notification.Name("toggleMainPanel")
    static let presentSettings = Notification.Name("presentSettings")
    static let dismissSettings = Notification.Name("dismissSettings")
}
