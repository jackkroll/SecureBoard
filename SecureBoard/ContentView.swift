//
//  ContentView.swift
//  SecureBoard
//
//  Created by Jack Kroll on 6/8/26.
//

import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var manager: PasteboardMonitor
    @Query var items: [PasteboardItem]

    var body: some View {
        VStack {
            ScrollView {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("SecureBoard")
                        .bold()
                }
                if let decryptionKey = manager.fetchKey() {
                    ForEach(items, id: \.id){ item in
                        HStack {
                            if let pasteboardItems = item.decryptContents(with: decryptionKey) {
                                PasteboardItemsView(pasteboardItems: pasteboardItems)
                            }
                            else {
                                Text("Unable to decrypt content with key")
                            }
                            Button {
                                modelContext.delete(item)
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "trash.fill")
                            }
                        }
                    }
                }
            }
        }
    }
}
struct PasteboardItemsView : View {
    let pasteboardItems: [NSPasteboardItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(pasteboardItems.enumerated()), id: \.offset) { _, item in
                displayType(for: item)
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func displayType(for item: NSPasteboardItem) -> some View {
        if let string = item.string(forType: .string), !string.isEmpty {
            Text(string)
                .textSelection(.enabled)
        } else if let fileURLString = item.string(forType: .fileURL), !fileURLString.isEmpty {
            Label(fileURLString, systemImage: "doc")
                .foregroundStyle(.blue)
                .textSelection(.enabled)
        } else if let image = image(for: item) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Text(item.types.map(\.rawValue).joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private func image(for item: NSPasteboardItem) -> NSImage? {
        if let data = item.data(forType: .png) ?? item.data(forType: .tiff) {
            return NSImage(data: data)
        }

        return nil
    }
}

#Preview {
    let container = try! ModelContainer(for: PasteboardItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    ContentView()
        .environmentObject(PasteboardMonitor(container: container, startsImmediately: false))
        .modelContainer(container)
}
