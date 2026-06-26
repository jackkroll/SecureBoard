//
//  ContentView.swift
//  SecureBoard
//
//  Created by Jack Kroll on 6/8/26.
//

import SwiftUI
import SwiftData
import AppKit
import CryptoKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var manager: PasteboardMonitor
    @Query(sort: \PasteboardItem.timestamp, order: .reverse) private var items: [PasteboardItem]
    @State private var isSettingsPresented = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .overlay {
            if isSettingsPresented {
                SettingsOverlay(isPresented: $isSettingsPresented)
                    .environmentObject(manager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentSettings)) { _ in
            isSettingsPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissSettings)) { _ in
            isSettingsPresented = false
        }
    }

    private func deleteItem(_ item: PasteboardItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func deleteAllItems() {
        for item in items {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 1) {
                Text("SecureBoard")
                    .font(.headline)
                Text("Encrypted clipboard history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .controlSize(.regular)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if items.isEmpty {
            ContentUnavailableView {
                Label("No Clipboard History", systemImage: "doc.on.clipboard")
            } description: {
                Text("Copied text, files, and images are saved here automatically.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let decryptionKey = manager.encryptionKey {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items, id: \.persistentModelID) { item in
                        ClipboardEntryRow(
                            item: item,
                            decryptionKey: decryptionKey,
                            onDelete: { deleteItem(item) }
                        )
                    }
                }
                .padding(12)
            }
        } else {
            ContentUnavailableView {
                Label("Key Unavailable", systemImage: "key.slash")
            } description: {
                Text("SecureBoard could not access the encryption key in your keychain.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        AppFooterView(itemCount: items.count, onDeleteAll: deleteAllItems)
    }
}

private struct SettingsOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .contentShape(Rectangle())
                .onTapGesture {
                    isPresented = false
                }

            SettingsView(onDismiss: { isPresented = false })
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 16, y: 4)
                .padding(12)
        }
    }
}

private struct AppFooterView: View {
    @ObservedObject private var appController = AppController.shared
    let itemCount: Int
    let onDeleteAll: () -> Void

    var body: some View {
        HStack {
            Text("\(itemCount) \(itemCount == 1 ? "entry" : "entries")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: onDeleteAll) {
                Text("Delete all entries")
            }
            Spacer()

            Text("Click a card to copy")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Quit") {
                appController.quit()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct ClipboardEntryRow: View {
    let item: PasteboardItem
    let decryptionKey: SymmetricKey
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: copyToClipboard) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.timestamp, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textCase(.lowercase)

                    if let pasteboardItems = item.decryptContents(with: decryptionKey) {
                        PasteboardItemsView(pasteboardItems: pasteboardItems)
                    } else {
                        Label("Unable to decrypt", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(CardButtonStyle(isHovering: isHovering))

            if isHovering {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete entry")
                .padding(12)
            }
        }
        .onHover { isHovering = $0 }
    }

    private func copyToClipboard() {
        guard
            let pasteboardItems = item.decryptContents(with: decryptionKey),
            !pasteboardItems.isEmpty
        else {
            return
        }

        NSPasteboard.general.prepareForNewContents()
        NSPasteboard.general.writeObjects(pasteboardItems)
    }
}

private struct PasteboardItemsView: View {
    let pasteboardItems: [NSPasteboardItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(pasteboardItems.enumerated()), id: \.offset) { _, item in
                displayType(for: item)
            }
        }
    }

    @ViewBuilder
    private func displayType(for item: NSPasteboardItem) -> some View {
        if let string = item.string(forType: .string), !string.isEmpty {
            ClipboardItemLabel(
                title: string,
                systemImage: "text.alignleft"
            )
        } else if let fileURLString = item.string(forType: .fileURL), !fileURLString.isEmpty {
            let fileInfo = fileDisplayInfo(from: fileURLString)
            ClipboardItemLabel(
                title: fileInfo.title,
                systemImage: "doc"
            )
        } else if let image = image(for: item) {
            HStack(spacing: 10) {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
                Text(item.types.map(\.rawValue).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func image(for item: NSPasteboardItem) -> NSImage? {
        if let data = item.data(forType: .png) ?? item.data(forType: .tiff) {
            return NSImage(data: data)
        }

        return nil
    }

    private func fileDisplayInfo(from fileURLString: String) -> (title: String, subtitle: String) {
        if let url = URL(string: fileURLString), url.scheme != nil {
            let title = url.lastPathComponent.isEmpty ? fileURLString : url.lastPathComponent
            return (title, fileURLString)
        }

        let title = URL(fileURLWithPath: fileURLString).lastPathComponent
        return (title.isEmpty ? fileURLString : title, fileURLString)
    }
}

private struct ClipboardItemLabel: View {
    let title: String
    var subtitle: String?
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CardButtonStyle: ButtonStyle {
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isHovering || configuration.isPressed ? 0.08 : 0.04))
            }
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return Color.accentColor.opacity(0.12)
        }
        if isHovering {
            return Color.primary.opacity(0.06)
        }
        return Color(nsColor: .controlBackgroundColor)
    }
}

#Preview {
    let container = try! ModelContainer(for: PasteboardItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    ContentView()
        .environmentObject(PasteboardMonitor(container: container, startsImmediately: false))
        .modelContainer(container)
        .frame(width: 380, height: 480)
}
