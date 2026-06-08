//
//  PasteboardMonitor.swift
//  SecureBoard
//
//  Created by Jack Kroll on 6/8/26.
//

import AppKit
import Combine
import CryptoKit
import KeychainSwift
import SwiftData

@MainActor
class PasteboardMonitor: ObservableObject {
    private let container: ModelContainer
    private var pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private var pendingCaptureWorkItem: DispatchWorkItem?
    private var lastSavedSnapshotHash: String?
    private let keychain = KeychainSwift()
    private let keychainStringKey = "secureboard.key"
    private let captureDelay: TimeInterval = 0.2

    init(container: ModelContainer, startsImmediately: Bool = true) {
        self.container = container
        lastChangeCount = pasteboard.changeCount

        if startsImmediately {
            startMonitoring()
        }
    }
    
    private func startMonitoring() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) {  _ in
            Task { @MainActor in
                let currentChangeCount = self.pasteboard.changeCount
                if currentChangeCount != self.lastChangeCount {
                    self.lastChangeCount = currentChangeCount
                    self.schedulePasteboardCapture(expectedChangeCount: currentChangeCount)
                }
            }
        }
    }

    private func schedulePasteboardCapture(expectedChangeCount: Int) {
        pendingCaptureWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.pasteboardChanged(expectedChangeCount: expectedChangeCount)
        }
        pendingCaptureWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + captureDelay, execute: workItem)
    }

    func fetchKey() -> SymmetricKey? {
        keychain.getData(keychainStringKey).map(SymmetricKey.init(data:))
    }

    private func existingOrNewKey() -> SymmetricKey {
        if let key = fetchKey() {
            return key
        }

        print("new key")
        let key = SymmetricKey(size: .bits256)
        keychain.set(key.withUnsafeBytes { Data($0) }, forKey: keychainStringKey)
        return key
    }

    private func pasteboardChanged(expectedChangeCount: Int) {
        guard pasteboard.changeCount == expectedChangeCount else { return }

        print("Pasteboard changed! New change count: \(expectedChangeCount)")
        let items = pasteboard.pasteboardItems ?? []
        guard !items.isEmpty else { return }

        let codableItems = items.map { CodablePasteboardItem(item: $0) }
        guard
            let payload = encodedPayload(items: codableItems),
            payload.snapshotHash != lastSavedSnapshotHash
        else {
            return
        }

        let key = existingOrNewKey()
        guard let sealedData = seal(payload.data, using: key) else { return }

        let savedItem = PasteboardItem(timestamp: .now, contents: sealedData)
        let context = ModelContext(container)
        context.insert(savedItem)

        do {
            try context.save()
            lastSavedSnapshotHash = payload.snapshotHash
        } catch {
            print("Unable to save pasteboard item: \(error)")
        }
    }
    
    private func encodedPayload(items: [CodablePasteboardItem]) -> (data: Data, snapshotHash: String)? {
        let payload = StoredPasteboardPayload(version: 1, items: items)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        guard let jsonEncoded = try? encoder.encode(payload) else { return nil }
        return (jsonEncoded, Self.snapshotHash(for: jsonEncoded))
    }

    private func seal(_ data: Data, using key: SymmetricKey) -> Data? {
        try? AES.GCM.seal(data, using: key).combined
    }
    
    deinit {
        timer?.invalidate()
        pendingCaptureWorkItem?.cancel()
    }
}

private extension PasteboardMonitor {
    static func snapshotHash(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct CodablePasteboardItem: Codable {
    let types: [String]
    let dataByType: [String: Data]

    init(item: NSPasteboardItem) {
        let typesUTIs = item.types.map { $0.rawValue }.sorted()
        types = typesUTIs

        var map: [String: Data] = [:]
        for typeString in typesUTIs {
            let type = NSPasteboard.PasteboardType(typeString)
            if let data = item.data(forType: type) {
                map[typeString] = data
            }
        }
        dataByType = map
    }

    func makePasteboardItem() -> NSPasteboardItem {
        let newItem = NSPasteboardItem()
        for typeString in types {
            let type = NSPasteboard.PasteboardType(typeString)
            if let data = dataByType[typeString] {
                newItem.setData(data, forType: type)
            }
        }
        return newItem
    }
}

struct StoredPasteboardPayload: Codable {
    let version: Int
    let items: [CodablePasteboardItem]
}
