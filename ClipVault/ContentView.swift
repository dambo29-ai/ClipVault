//
//  ContentView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/8/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

private struct ClipboardRowPresentationID:
    Hashable
{
    let itemID: UUID
    let isPinned: Bool
    let displayNumber: Int?
}

private enum ClipboardContentFilter:
    String,
    CaseIterable,
    Identifiable
{
    case all = "All"
    case text = "Text"
    case links = "Links"
    case images = "Images"
    case files = "Files"

    var id: Self {
        self
    }
}

struct ContentView: View {
    @EnvironmentObject var clipboardStore: ClipboardStore
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""
    @State private var selectedContentFilter:
        ClipboardContentFilter = .all

    @AppStorage("isPinnedSectionExpanded")
    private var isPinnedSectionExpanded = true

    @AppStorage("isRecentSectionExpanded")
    private var isRecentSectionExpanded = true

    @State private var isBackupDropTargeted = false
    @FocusState private var isSearchFocused: Bool
    
    private var contentFilteredItems: [ClipboardItem] {
        switch selectedContentFilter {
        case .all:
            return clipboardStore.items

        case .text:
            return clipboardStore.items.filter {
                guard $0.kind == .normal else {
                    return true
                }

                return $0.contentKind == .text
            }

        case .links:
            return clipboardStore.items.filter {
                $0.kind == .normal &&
                $0.contentKind == .link
            }

        case .images:
            return clipboardStore.items.filter {
                $0.kind == .normal &&
                $0.contentKind == .image
            }

        case .files:
            return clipboardStore.items.filter {
                $0.kind == .normal &&
                $0.contentKind == .files
            }
        }
    }
    
    private var filteredItems: [ClipboardItem] {
        let trimmedSearchText =
            searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmedSearchText.isEmpty else {
            return contentFilteredItems
        }

        return contentFilteredItems.filter {
            $0.searchableText
                .localizedCaseInsensitiveContains(
                    trimmedSearchText
                )
        }
    }
    
    private var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        .isEmpty
    }
    
    private var clearContentScope:
        ClipboardClearContentScope
    {
        switch selectedContentFilter {
        case .all:
            return .all

        case .text:
            return .text

        case .links:
            return .links

        case .images:
            return .images

        case .files:
            return .files
        }
    }

    private var clearScopeResult:
        ClipboardClearScopeResult
    {
        ClipboardClearScopeService.result(
            from: clipboardStore.items,
            contentScope: clearContentScope,
            searchText: searchText
        )
    }

    private var clearUnpinnedDescriptor:
        ClipboardClearConfirmationDescriptor
    {
        ClearHistoryConfirmation.descriptor(
            for: clearScopeResult,
            contentScope: clearContentScope,
            hasActiveSearch: hasActiveSearch,
            mode: .unpinned
        )
    }

    private var clearIncludingPinnedDescriptor:
        ClipboardClearConfirmationDescriptor
    {
        ClearHistoryConfirmation.descriptor(
            for: clearScopeResult,
            contentScope: clearContentScope,
            hasActiveSearch: hasActiveSearch,
            mode: .includingPinned
        )
    }

    private var pinnedItems: [ClipboardItem] {
        filteredItems
            .filter {
                $0.kind == .normal &&
                $0.isPinned
            }
            .sorted {
                ($0.pinnedAt ?? .distantPast) >
                ($1.pinnedAt ?? .distantPast)
            }
    }

    private var recentItems: [ClipboardItem] {
        filteredItems.filter {
            !$0.isPinned
        }
    }

    private var pinnedItemCount: Int {
        pinnedItems.filter {
            $0.kind == .normal
        }
        .count
    }

    private var recentItemCount: Int {
        recentItems.filter {
            $0.kind == .normal
        }
        .count
    }

    private var shouldShowPinnedRows: Bool {
        hasActiveSearch || isPinnedSectionExpanded
    }

    private var shouldShowRecentRows: Bool {
        hasActiveSearch || isRecentSectionExpanded
    }
    
    private var highlightedPinnedItemIsVisible: Bool {
        guard
            let highlightedPinnedItemID =
                clipboardStore.highlightedPinnedItemID
        else {
            return false
        }

        return pinnedItems.contains {
            $0.id == highlightedPinnedItemID
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            contentFilterView
            
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
                            
                            Text(
                                "Drop a ClipVault Backup or Image to Import"
                            )
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
        .onChange(
            of: clipboardStore.highlightedPinnedItemID
        ) {
            _,
            highlightedItemID in

            guard highlightedItemID != nil else {
                return
            }

            if highlightedPinnedItemIsVisible {
                isPinnedSectionExpanded = true
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
                
                Menu("Clear") {
                    Button(
                        clearUnpinnedDescriptor.menuTitle
                    ) {
                        clearUnpinnedItemsInCurrentScope()
                    }
                    .disabled(
                        clearScopeResult
                            .unpinnedItemIDsIncludingWarnings
                            .isEmpty
                    )

                    Divider()

                    Button(
                        clearIncludingPinnedDescriptor.menuTitle,
                        role: .destructive
                    ) {
                        clearAllItemsInCurrentScope()
                    }
                    .disabled(
                        clearScopeResult.allItemIDs.isEmpty
                    )
                }
                .disabled(clearScopeResult.isEmpty)
                
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
    
    private var contentFilterView: some View {
        Picker(
            "Clipboard content",
            selection: $selectedContentFilter
        ) {
            ForEach(ClipboardContentFilter.allCases) {
                contentFilter in
                
                Text(contentFilter.rawValue)
                    .tag(contentFilter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .accessibilityLabel("Clipboard content filter")
    }
    
    private var searchView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            
            TextField(
                searchFieldPlaceholder,
                text: $searchText
            )
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
    
    private var searchFieldPlaceholder: String {
        switch selectedContentFilter {
        case .all:
            return "Search clipboard history"
            
        case .text:
            return "Search text"
            
        case .links:
            return "Search links"
            
        case .images:
            return "Search images"
            
        case .files:
            return "Search files"
        }
    }
    
    private var clipboardListView: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 0
            ) {
                if !pinnedItems.isEmpty {
                    listSectionHeader(
                        title: "Pinned",
                        itemCount: pinnedItemCount,
                        isExpanded:
                            shouldShowPinnedRows,
                        toggleExpanded: {
                            guard !hasActiveSearch else {
                                return
                            }

                            isPinnedSectionExpanded.toggle()
                        }
                    )

                    if shouldShowPinnedRows {
                        clipboardRows(
                            pinnedItems,
                            displaysNumbers: false
                        )
                    }
                }

                if !recentItems.isEmpty {
                    if !pinnedItems.isEmpty {
                        sectionSpacing
                    }

                    listSectionHeader(
                        title: "Recent",
                        itemCount: recentItemCount,
                        isExpanded:
                            shouldShowRecentRows,
                        toggleExpanded: {
                            guard !hasActiveSearch else {
                                return
                            }

                            isRecentSectionExpanded.toggle()
                        }
                    )

                    if shouldShowRecentRows {
                        clipboardRows(
                            recentItems,
                            displaysNumbers: true
                        )
                    }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    private var sectionSpacing: some View {
        VStack(spacing: 10) {
            Divider()

            Color.clear
                .frame(height: 2)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func clipboardRows(
        _ items: [ClipboardItem],
        displaysNumbers: Bool
    ) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) {
            index,
            item in

            let rowDisplayNumber =
                displaysNumbers &&
                item.kind == .normal
                    ? displayNumber(for: item)
                    : nil

            ClipboardRow(
                item: item,
                displayNumber: rowDisplayNumber,
                isHighlighted:
                    clipboardStore.highlightedPinnedItemID ==
                        item.id,
                onCopy: {
                    clipboardStore.copyToClipboard(item)
                },
                onPin: {
                    isPinnedSectionExpanded = true
                    clipboardStore.pinItem(item)
                },
                onUnpin: {
                    isRecentSectionExpanded = true
                    clipboardStore.unpinItem(item)
                },
                onDelete: {
                    clipboardStore.deleteItem(item)
                }
            )
            .id(
                ClipboardRowPresentationID(
                    itemID: item.id,
                    isPinned: item.isPinned,
                    displayNumber: rowDisplayNumber
                )
            )

            if index < items.count - 1 {
                Divider()
            }
        }
    }

    private func listSectionHeader(
        title: String,
        itemCount: Int,
        isExpanded: Bool,
        toggleExpanded: @escaping () -> Void
    ) -> some View {
        Button(action: toggleExpanded) {
            HStack(spacing: 6) {
                Image(
                    systemName:
                        isExpanded
                            ? "chevron.down"
                            : "chevron.right"
                )
                .font(
                    .system(
                        size: 10,
                        weight: .semibold
                    )
                )
                .frame(width: 12)
                .accessibilityHidden(true)

                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(itemCount)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .accessibilityLabel(
            "\(title), \(itemCount) items"
        )
        .accessibilityValue(
            isExpanded
                ? "Expanded"
                : "Collapsed"
        )
        .accessibilityHint(
            hasActiveSearch
                ? "Sections remain expanded while searching"
                : "Toggle section visibility"
        )
    }
    
    private func displayNumber(
        for item: ClipboardItem
    ) -> Int? {
        let visibleRecentNormalItems =
            recentItems.filter {
                $0.kind == .normal
            }

        guard
            let index =
                visibleRecentNormalItems.firstIndex(
                    where: {
                        $0.id == item.id
                    }
                )
        else {
            return nil
        }

        return visibleRecentNormalItems.count - index
    }
    
    @MainActor
    private func clearUnpinnedItemsInCurrentScope() {
        let descriptor =
            clearUnpinnedDescriptor

        guard
            ClearHistoryConfirmation.shouldClear(
                descriptor: descriptor
            )
        else {
            return
        }

        clipboardStore.removeItems(
            withIDs:
                clearScopeResult
                    .unpinnedItemIDsIncludingWarnings
        )
    }

    @MainActor
    private func clearAllItemsInCurrentScope() {
        let descriptor =
            clearIncludingPinnedDescriptor

        guard
            ClearHistoryConfirmation.shouldClear(
                descriptor: descriptor
            )
        else {
            return
        }

        clipboardStore.removeItems(
            withIDs:
                clearScopeResult.allItemIDs
        )
    }
    
    private func handleDroppedBackupProviders(
        _ providers: [NSItemProvider]
    ) -> Bool {
        let fileProviders =
            providers.filter {
                $0.hasItemConformingToTypeIdentifier(
                    UTType.fileURL.identifier
                )
            }

        guard !fileProviders.isEmpty else {
            return false
        }

        let collector =
            DroppedFileBatchCollector(
                expectedCount:
                    fileProviders.count
            )

        for (index, provider) in
            fileProviders.enumerated()
        {
            provider.loadItem(
                forTypeIdentifier:
                    UTType.fileURL.identifier,
                options: nil
            ) {
                item,
                error in

                let droppedURL: URL?

                if error != nil {
                    droppedURL = nil
                } else if let data =
                    item as? Data
                {
                    droppedURL =
                        URL(
                            dataRepresentation:
                                data,
                            relativeTo: nil
                        )
                } else if let url =
                    item as? URL
                {
                    droppedURL = url
                } else {
                    droppedURL = nil
                }

                Task {
                    guard
                        let result =
                            await collector.record(
                                index: index,
                                fileURL:
                                    droppedURL
                            )
                    else {
                        return
                    }

                    await MainActor.run {
                        importDroppedFiles(
                            result.fileURLs,
                            failedProviderCount:
                                result
                                    .failedProviderCount
                        )
                    }
                }
            }
        }

        return true
    }
    
    @MainActor
    private func importDroppedFiles(
        _ fileURLs: [URL],
        failedProviderCount: Int
    ) {
        guard !fileURLs.isEmpty else {
            OperationFailureAlert.show(
                title:
                    "Import Failed",
                message:
                    "ClipVault could not read the dropped files."
            )

            return
        }

        let packageBackupURLs =
            fileURLs.filter {
                $0.pathExtension
                    .localizedCaseInsensitiveCompare(
                        ClipboardBackupPackageService
                            .packageExtension
                    ) ==
                    .orderedSame
            }

        let legacyJSONBackupURLs =
            fileURLs.filter {
                $0.pathExtension
                    .localizedCaseInsensitiveCompare(
                        "json"
                    ) ==
                    .orderedSame
            }

        let backupURLs =
            packageBackupURLs +
            legacyJSONBackupURLs

        if !backupURLs.isEmpty {
            guard
                backupURLs.count == 1,
                fileURLs.count == 1,
                failedProviderCount == 0
            else {
                OperationFailureAlert.show(
                    title:
                        "Import Failed",
                    message:
                        """
                        A ClipVault backup must be dropped by itself. Drop one .clipvaultbackup package, one legacy JSON backup, or only image files.
                        """
                )

                return
            }

            importDroppedBackup(
                from:
                    backupURLs[0]
            )

            return
        }

        Task { @MainActor in
            let result =
                await clipboardStore
                    .importImageFiles(
                        at: fileURLs
                    )

            if result.importedCount > 0 {
                selectedContentFilter =
                    .images

                isRecentSectionExpanded =
                    true
            }

            let totalFailedCount =
                result.failedFilenames.count +
                failedProviderCount

            guard totalFailedCount > 0 else {
                return
            }

            let failedWord =
                totalFailedCount == 1
                    ? "file"
                    : "files"

            var message =
                "\(totalFailedCount) \(failedWord) could not be imported as an image."

            if !result.failedFilenames.isEmpty {
                message +=
                    "\n\n" +
                    result.failedFilenames
                        .map {
                            "• \($0)"
                        }
                        .joined(
                            separator: "\n"
                        )
            }

            message +=
                "\n\nPDFs and unsupported or invalid files are not accepted as images."

            OperationFailureAlert.show(
                title:
                    result.importedCount > 0
                        ? "Some Images Were Not Imported"
                        : "Image Import Failed",
                message:
                    message
            )
        }
    }
    
    @MainActor
    private func importDroppedBackup(
        from backupURL: URL
    ) {
        Task { @MainActor in
            do {
                let pathExtension =
                    backupURL
                        .pathExtension
                        .lowercased()

                if pathExtension ==
                    ClipboardBackupPackageService
                        .packageExtension
                {
                    let packageContents =
                        try ClipboardBackupPackageImportService
                            .shared
                            .readPackage(
                                at:
                                    backupURL
                            )

                    let restoration =
                        try await ClipboardBackupPackageImportService
                            .shared
                            .restorePackage(
                                packageContents
                            )

                    await BackupImportWorkflow
                        .handlePackageRestoration(
                            restoration,
                            clipboardStore:
                                clipboardStore
                        )
                } else if pathExtension ==
                            "json"
                {
                    let backupItems =
                        try ClipboardImportService
                            .itemsFromJSONBackup(
                                at:
                                    backupURL
                            )

                    BackupImportWorkflow.handle(
                        backupItems:
                            backupItems,
                        clipboardStore:
                            clipboardStore
                    )
                } else {
                    OperationFailureAlert.show(
                        title:
                            "Backup Import Failed",
                        message:
                            "Drop a .clipvaultbackup package or a legacy ClipVault JSON backup."
                    )
                }
            } catch {
                OperationFailureAlert.show(
                    title:
                        "Backup Import Failed",
                    message:
                        "ClipVault could not import the dropped backup.",
                    error:
                        error
                )
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(
                systemName:
                    hasActiveSearch
                ? "magnifyingglass"
                : emptyStateSymbolName
            )
            .font(
                .system(
                    size: hasActiveSearch ? 32 : 48
                )
            )
            .foregroundStyle(.secondary)
            
            Text(
                hasActiveSearch
                ? "No matching clips found"
                : emptyStateTitle
            )
            .font(.headline)
            
            if hasActiveSearch {
                Text("Try a different search term.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(emptyStateDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }
    
    private var emptyStateSymbolName: String {
        switch selectedContentFilter {
        case .all:
            return "doc.on.clipboard"
            
        case .text:
            return "text.alignleft"
            
        case .links:
            return "link"
            
        case .images:
            return "photo"
            
        case .files:
            return "doc"
        }
    }
    
    private var emptyStateTitle: String {
        switch selectedContentFilter {
        case .all:
            return "No clipboard history yet"
            
        case .text:
            return "No copied text yet"
            
        case .links:
            return "No copied links yet"
            
        case .images:
            return "No copied images yet"
            
        case .files:
            return "No copied files yet"
        }
    }
    
    private var emptyStateDescription: String {
        switch selectedContentFilter {
        case .all:
            return
                """
                Copy something from anywhere on your Mac, \
                and it will appear here.
                """
            
        case .text:
            return
                """
                Copy text from anywhere on your Mac, \
                and it will appear here.
                """
            
        case .links:
            return
                """
                Copied links will appear here once \
                link classification is enabled.
                """
            
        case .images:
            return
                """
                Drag an image into ClipVault to add it \
                to your image history.
                """
            
        case .files:
            return
                """
                Copied files will appear here once \
                file support is enabled.
                """
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ClipboardStore())
}

private actor DroppedFileBatchCollector {
    struct Result {
        let fileURLs: [URL]
        let failedProviderCount: Int
    }

    private let expectedCount: Int

    private var fileURLsByIndex:
        [Int: URL] = [:]

    private var failedProviderCount = 0
    private var completedCount = 0

    init(
        expectedCount: Int
    ) {
        self.expectedCount =
            expectedCount
    }

    func record(
        index: Int,
        fileURL: URL?
    ) -> Result? {
        completedCount += 1

        if let fileURL {
            fileURLsByIndex[index] =
                fileURL
        } else {
            failedProviderCount += 1
        }

        guard
            completedCount ==
                expectedCount
        else {
            return nil
        }

        let orderedFileURLs =
            (0..<expectedCount)
                .compactMap {
                    fileURLsByIndex[$0]
                }

        return Result(
            fileURLs:
                orderedFileURLs,
            failedProviderCount:
                failedProviderCount
        )
    }
}
