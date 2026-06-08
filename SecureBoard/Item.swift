//
//  Item.swift
//  SecureBoard
//
//  Created by Jack Kroll on 6/8/26.
//

import Foundation
import SwiftData
import AppKit
import CryptoKit

@Model
final class PasteboardItem {
    var timestamp: Date
    var contents: Data
    
    init(timestamp: Date, contents: Data) {
        self.timestamp = timestamp
        self.contents = contents
    }
    
    @MainActor func decryptContents(with key: SymmetricKey) -> [NSPasteboardItem]? {
        if let items = try? decodeItems(from: contents, using: key) {
            return items.isEmpty ? nil : items
        }

        return nil
    }

    @MainActor private func decodeItems(from data: Data, using key: SymmetricKey) throws -> [NSPasteboardItem] {
        if let encryptedItems = try? decodeEncryptedItems(from: data, using: key) {
            return encryptedItems
        }

        throw DecryptionError.unableToDecode
    }

    @MainActor private func decodeEncryptedItems(from data: Data, using key: SymmetricKey) throws -> [NSPasteboardItem] {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        return try decodePayload(from: decryptedData)
    }

    @MainActor private func decodePayload(from data: Data) throws -> [NSPasteboardItem] {
        let decoder = JSONDecoder()

        if let payload = try? decoder.decode(StoredPasteboardPayload.self, from: data) {
            return payload.items.compactMap { $0.makePasteboardItem() }
        }

        let codableItems = try decoder.decode([CodablePasteboardItem].self, from: data)
        return codableItems.compactMap { $0.makePasteboardItem() }
    }

    private enum DecryptionError: Error {
        case unableToDecode
    }
    
}
