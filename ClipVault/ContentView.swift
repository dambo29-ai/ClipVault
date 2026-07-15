//
//  ContentView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/8/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var clipboardStore: ClipboardStore
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""
    @State private var isBackupDropTargeted = false
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [ClipboardItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return clipboardStore.items
        }

        return clipboardStore.items.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            searchView
            
            Divider()
            
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                clipboardListView
            }
        }
        .frame(minWidth: 480, minHeight: 400)
        .overlay {
            if isBackupDropTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .padding(12)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 32))
                            
                            Text("Drop ClipVault Backup to Import")
                                .font(.headline)
                        }
                        .padding(20)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
            }
        }
        .onDrop(
            of: [.fileURL],
            isTargeted: $isBackupDropTargeted,
            perform: handleDroppedBackupProviders
        )
        .onExitCommand {
            if isSearchFocused && !searchText.isEmpty {
                searchText = ""
            } else if isSearchFocused {
                isSearchFocused = false
            }
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 16) {
            Spacer(minLength: 20)

            HStack(alignment: .center, spacing: 12) {
                Toggle(
                    "Pause",
                    isOn: $clipboardStore.isMonitoringPaused
                )
                .toggleStyle(.switch)
                .fixedSize(
                    horizontal: true,
                    vertical: false
                )

                Button("Clear") {
                    if ClearHistoryConfirmation.shouldClearHistory() {
                        clipboardStore.clearHistory()
                    }
                }
                .disabled(clipboardStore.items.isEmpty)

                Button {
                    openWindow(id: "settings-window")
                    NSApplication.shared.activate(
                        ignoringOtherApps: true
                    )
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Open settings")
                .accessibilityLabel("Open settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var searchView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            TextField("Search copied text", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var clipboardListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredItems) { item in
                    ClipboardRow(
                        item: item,
                        displayNumber:
                            item.kind == .normal
                                ? displayNumber(for: item)
                                : nil,
                        onCopy: {
                            clipboardStore.copyToClipboard(item)
                        },
                        onDelete: {
                            clipboardStore.deleteItem(item)
                        }
                    )

                    if item.id != filteredItems.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    private func displayNumber(for item: ClipboardItem) -> Int? {
        let normalItems =
            clipboardStore.items.filter {
                $0.kind == .normal
            }

        guard
            let index =
                normalItems.firstIndex(
                    where: {
                        $0.id == item.id
                    }
                )
        else {
            return nil
        }

        return normalItems.count - index
    }

    private func handleDroppedBackupProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }
        
        provider.loadItem(
            forTypeIdentifier: UTType.fileURL.identifier,
            options: nil
        ) { item, error in
            if let error {
                Task { @MainActor in
                    OperationFailureAlert.show(
                        title: "Backup Import Failed",
                        message:
                            "ClipVault could not import the dropped backup file.",
                        error: error
                    )
                }
                return
            }
            
            let droppedURL: URL?
            
            if let data = item as? Data {
                droppedURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                droppedURL = url
            } else {
                droppedURL = nil
            }
            
            guard let droppedURL else {
                Task { @MainActor in
                    OperationFailureAlert.show(
                        title: "Backup Import Failed",
                        message: "Only JSON backup files can be imported."
                    )
                }
                return
            }
            
            Task { @MainActor in
                importDroppedBackup(from: droppedURL)
            }
        }
        
        return true
    }

    @MainActor
    private func importDroppedBackup(from backupURL: URL) {
        do {
            let backupItems =
                try ClipboardImportService.itemsFromJSONBackup(
                    at: backupURL
                )

            BackupImportWorkflow.handle(
                backupItems: backupItems,
                clipboardStore: clipboardStore,
                openSettings: {
                    openWindow(id: "settings-window")
                }
            )
        } catch {
            OperationFailureAlert.show(
                title: "Backup Import Failed",
                message:
                    "ClipVault could not import the dropped backup file.",
                error: error
            )
        }
    }

    private var emptyStateView: some View {
        let hasActiveSearch =
            !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(spacing: 12) {
            Image(
                systemName: hasActiveSearch
                    ? "magnifyingglass"
                    : "doc.on.clipboard"
            )
            .font(.system(size: hasActiveSearch ? 32 : 48))
            .foregroundStyle(.secondary)

            Text(
                hasActiveSearch
                    ? "No matching clips found"
                    : "No copied text yet"
            )
            .font(.headline)

            if hasActiveSearch {
                Text("Try a different search term.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 6) {
                    Text(
                        "Copy text from anywhere on your Mac, and it will appear here."
                    )

                    Text(
                        "You can also drag a ClipVault JSON backup file into this window to import it."
                    )
                    .font(.caption)
                }
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }
}

#Preview {
    ContentView()
        .environmentObject(ClipboardStore())
}
