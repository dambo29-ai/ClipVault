//
//  ClipboardStore.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/8/26.
//

import Foundation
import AppKit
import Combine

private struct DefaultAppGroup {
    let groupID: String
    let displayName: String
    let bundleIdentifiers: [String]
}

enum ClipboardCaptureSource {
    case nativeClipboard
    case optionSelect
}

enum ClipboardCaptureOutcome: Equatable {
    case captured
    case skippedMonitoringPaused
    case skippedEmpty
    case skippedBlocked
    case skippedSensitive
}

enum ClipboardBackupImportOutcome {
    case imported(
        importedCount: Int,
        duplicateCount: Int
    )

    case exceedsHistoryLimit(
        itemsOverLimit: Int
    )
}

struct ClipboardBackupReplacementResult {
    let imported: Int
    let duplicates: Int
    let skippedDueToLimit: Int
}

enum ClipboardBackupImportMode:
    Equatable,
    Sendable
{
    case merge
    case replace
}

struct ClipboardBackupImportPlan:
    Equatable,
    Sendable
{
    let mode: ClipboardBackupImportMode
    let preparedItems: [ClipboardItem]
    let importedItemIDs: Set<UUID>
    let duplicateCount: Int
    let requiredUnpinnedItemCount: Int

    var importedCount: Int {
        importedItemIDs.count
    }
}

struct ClipboardBackupImportApplicationResult:
    Equatable,
    Sendable
{
    let mode: ClipboardBackupImportMode
    let importedCount: Int
    let duplicateCount: Int
    let skippedDueToLimitCount: Int
    let resultingHistoryLimit: Int
    let didExpandHistoryLimit: Bool
}

struct ClipboardImageBatchImportResult {
    let importedCount: Int
    let pinnedDuplicateCount: Int
    let failedFilenames: [String]
}

struct ClipboardFilesImportResult {
    let importedCount: Int
    let pinnedDuplicateCount: Int
    let failedFilenames: [String]
}

@MainActor
final class ClipboardStore: ObservableObject {
    static let minimumHistoryLimit = 10
    static let maximumHistoryLimit = 500

    static let minimumBackupKeepCount = 1
    static let maximumBackupKeepCount = 50
    
    @Published var items: [ClipboardItem] = []
    @Published var isMonitoringPaused: Bool = false
    @Published private(set) var maxItemCount: Int = 100
    @Published private(set) var historyRetentionOption: HistoryRetentionOption = .forever
    @Published private(set) var showsSkippedClipWarnings:
        Bool =
            true

    @Published private(set) var blocksLikelySensitiveClips:
        Bool =
            true

    @Published private(set) var backupKeepCount:
        Int =
            5
    @Published private(set) var knownAppRecords: [String: KnownAppRecord] = [:]
    @Published private(set) var appRuleModes: [String: AppRuleMode] = [:]
    @Published private(set) var isRefreshingAvailableApps = false
    @Published private(set) var highlightedPinnedItemID: UUID?
    
    private let maxItemCountKey = "maxItemCount"
    private let historyRetentionOptionKey = "historyRetentionOption"
    private let showsSkippedClipWarningsKey =
        "showsSkippedClipWarnings"

    private let blocksLikelySensitiveClipsKey =
        "blocksLikelySensitiveClips"

    private let backupKeepCountKey =
        "backupKeepCount"
    private let knownAppRecordsKey = "knownAppRecords"
    private let appRuleModesKey = "appRuleModes"
    
    private let appDiscoveryService =
        AppDiscoveryService()

    private let clipboardMonitoringService =
        ClipboardMonitoringService()

    private let imageStorageService:
        ClipboardImageStorageService

    private let imagePasteboardService:
        ClipboardImagePasteboardService
    
    private let fileReferenceService:
        ClipboardFileReferenceService
    
    private let filesPasteboardService:
        ClipboardFilesPasteboardService

    private let mixedFilesPasteboardService:
        ClipboardMixedFilesPasteboardService

    private var appDiscoveryTask: Task<Void, Never>?
    private var pinnedHighlightTask: Task<Void, Never>?

    private var currentClipboardItemIDs:
        [UUID] = []

    private var currentClipboardChangeCount:
        Int?
    
    private let automatedScreenshotCapturePolicyService =
        AutomatedScreenshotCapturePolicyService()
    
    // Old key retained only so we can migrate existing Allowed/Blocked choices.
    private let legacyBlockedAppGroupIDsKey = "blockedAppGroupIDs"
    
    private let defaultAppGroups: [DefaultAppGroup] = [
        DefaultAppGroup(
            groupID: "1password",
            displayName: "1Password",
            bundleIdentifiers: [
                "com.1password.1password",
                "com.1password.1password-safari",
                "com.1password.1password.safari",
                "com.agilebits.onepassword",
                "com.agilebits.onepassword7"
            ]
        ),
        DefaultAppGroup(
            groupID: "bitwarden",
            displayName: "Bitwarden",
            bundleIdentifiers: [
                "com.8bit.bitwarden",
                "com.bitwarden.desktop",
                "com.bitwarden.safari"
            ]
        ),
        DefaultAppGroup(
            groupID: "nordpass",
            displayName: "NordPass",
            bundleIdentifiers: [
                "com.nordpass.NordPass",
                "com.nordpass.desktop",
                "com.nordpass.macos",
                "com.nordsec.nordpass"
            ]
        ),
        DefaultAppGroup(
            groupID: "keychain-access",
            displayName: "Keychain Access",
            bundleIdentifiers: [
                "com.apple.keychainaccess"
            ]
        )
    ]
    
    var appRuleOptions: [AppRuleOption] {
        let groupedRecords = Dictionary(grouping: knownAppRecords.values) { record in
            record.groupID
        }
        
        return groupedRecords.map { groupID, records in
            let displayName = displayNameForGroupID(groupID) ?? records
                .map { $0.displayName }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .first ?? groupID
            
            let bundleIdentifiers = records
                .map { $0.bundleIdentifier }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            
            let iconFilePath = records
                .compactMap { $0.appPath }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .first
            
            return AppRuleOption(
                id: groupID,
                displayName: displayName,
                bundleIdentifiers: bundleIdentifiers,
                iconFilePath: iconFilePath
            )
        }
        .sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
    
    private var defaultBundleIdentifierToGroupID: [String: String] {
        var result: [String: String] = [:]
        
        for group in defaultAppGroups {
            for bundleIdentifier in group.bundleIdentifiers {
                result[bundleIdentifier.lowercased()] = group.groupID
            }
        }
        
        return result
    }
    
    private var defaultGroupIDToDisplayName: [String: String] {
        var result: [String: String] = [:]
        
        for group in defaultAppGroups {
            result[group.groupID] = group.displayName
        }
        
        return result
    }
    
    init(
        imageStorageService:
            ClipboardImageStorageService =
                .shared,
        fileReferenceService:
            ClipboardFileReferenceService? =
                nil
    ) {
        self.imageStorageService =
            imageStorageService

        let resolvedFileReferenceService =
            fileReferenceService ??
            ClipboardFileReferenceService
                .shared

        self.fileReferenceService =
            resolvedFileReferenceService

        filesPasteboardService =
            ClipboardFilesPasteboardService(
                fileReferenceService:
                    resolvedFileReferenceService
            )

        mixedFilesPasteboardService =
            ClipboardMixedFilesPasteboardService(
                imageStorageService:
                    imageStorageService,
                fileReferenceService:
                    resolvedFileReferenceService
            )

        imagePasteboardService =
            ClipboardImagePasteboardService(
                imageStorageService:
                    imageStorageService,
                fileReferenceService:
                    resolvedFileReferenceService
            )

        loadMaxItemCount()
        loadHistoryRetentionOption()
        loadSkippedClipWarningPreference()
        loadSensitiveClipProtectionPreference()
        loadBackupKeepCount()
        loadKnownAppRecords()
        loadAppRuleModes()
        loadItems()

        let loadedItems =
            items

        items =
            retainedItems(
                from: items
            )

        if items != loadedItems {
            finalizeHistoryMutation(
                previousItems:
                    loadedItems
            )
        }

        clipboardMonitoringService.start {
            [weak self] payload in

            self?.handleClipboardChange(
                payload
            )
        }
    }
    
    func importImageFiles(
        at fileURLs: [URL],
        sourceAppName:
            String = "Manual Import",
        sourceBundleIdentifier:
            String? = nil
    ) async -> ClipboardImageBatchImportResult {
        guard !fileURLs.isEmpty else {
            return ClipboardImageBatchImportResult(
                importedCount: 0,
                pinnedDuplicateCount: 0,
                failedFilenames: []
            )
        }

        var workingItems = items
        var importedItems: [ClipboardItem] = []
        var importedItemIDs: Set<UUID> = []

        var imagePayloadsToDelete:
            [ClipboardImagePayload] = []

        var pinnedDuplicateItemIDs:
            [UUID] = []

        var failedFilenames:
            [String] = []

        for fileURL in fileURLs {
            let didAccessSecurityScopedResource =
                fileURL
                    .startAccessingSecurityScopedResource()

            defer {
                if didAccessSecurityScopedResource {
                    fileURL
                        .stopAccessingSecurityScopedResource()
                }
            }

            do {
                let originalFileReference =
                    try? fileReferenceService
                        .makeReference(
                            for:
                                fileURL
                        )

                let imagePayload =
                    try await imageStorageService
                        .storeImage(
                            at:
                                fileURL,
                            originalFileReference:
                                originalFileReference
                        )

                let duplicateKey =
                    imagePayload.duplicateKey

                if let pinnedItem =
                    workingItems.first(
                        where: {
                            $0.kind == .normal &&
                            $0.isPinned &&
                            $0.duplicateKey ==
                                duplicateKey
                        }
                    )
                {
                    imagePayloadsToDelete.append(
                        imagePayload
                    )

                    pinnedDuplicateItemIDs.append(
                        pinnedItem.id
                    )

                    continue
                }

                let duplicateItems =
                    workingItems.filter {
                        $0.kind == .normal &&
                        !$0.isPinned &&
                        $0.duplicateKey ==
                            duplicateKey
                    }

                let duplicateItemIDs =
                    Set(
                        duplicateItems.map(\.id)
                    )

                workingItems.removeAll {
                    duplicateItemIDs.contains(
                        $0.id
                    )
                }

                importedItems.removeAll {
                    duplicateItemIDs.contains(
                        $0.id
                    )
                }

                for duplicateItem in duplicateItems {
                    if let duplicateImagePayload =
                        duplicateItem.imagePayload
                    {
                        imagePayloadsToDelete.append(
                            duplicateImagePayload
                        )
                    }
                }

                let newItem =
                    ClipboardItem(
                        payload:
                            .image(
                                imagePayload
                            ),
                        createdAt: Date(),
                        sourceAppName:
                            sourceAppName,
                        sourceBundleIdentifier:
                            sourceBundleIdentifier
                    )

                importedItems.append(
                    newItem
                )

                importedItemIDs.insert(
                    newItem.id
                )
            } catch {
                failedFilenames.append(
                    fileURL.lastPathComponent
                )
            }
        }

        items =
            importedItems +
            workingItems

        let itemsBeforeRetention =
            items

        items =
            retainedItems(
                from: items
            )

        let retainedItemIDs =
            Set(
                items.map(\.id)
            )

        for removedItem in itemsBeforeRetention
        where !retainedItemIDs.contains(
            removedItem.id
        ) {
            if let removedImagePayload =
                removedItem.imagePayload
            {
                imagePayloadsToDelete.append(
                    removedImagePayload
                )
            }
        }

        let survivingImportedCount =
            importedItemIDs.filter {
                retainedItemIDs.contains($0)
            }
            .count

        saveItems()

        for imagePayload in imagePayloadsToDelete {
            try? await imageStorageService
                .deleteImage(
                    for: imagePayload
                )
        }

        if let highlightedItemID =
            pinnedDuplicateItemIDs.last
        {
            signalPinnedDuplicate(
                itemID: highlightedItemID
            )
        }

        return ClipboardImageBatchImportResult(
            importedCount:
                survivingImportedCount,
            pinnedDuplicateCount:
                pinnedDuplicateItemIDs.count,
            failedFilenames:
                failedFilenames
        )
    }
    
    func importFileURLs(
        _ fileURLs: [URL],
        sourceAppName:
            String = "Manual Import",
        sourceBundleIdentifier:
            String? = nil
    ) -> ClipboardFilesImportResult {
        guard !fileURLs.isEmpty else {
            return ClipboardFilesImportResult(
                importedCount: 0,
                pinnedDuplicateCount: 0,
                failedFilenames: []
            )
        }

        let referenceResult =
            fileReferenceService
                .makeReferences(
                    for:
                        fileURLs
                )

        let failedFilenames =
            referenceResult
                .failedURLs
                .map(\.lastPathComponent)

        guard
            !referenceResult
                .references
                .isEmpty
        else {
            return ClipboardFilesImportResult(
                importedCount: 0,
                pinnedDuplicateCount: 0,
                failedFilenames:
                    failedFilenames
            )
        }

        let previousItems =
            items

        var updatedItems =
            items

        var newItems:
            [ClipboardItem] = []

        var pinnedDuplicateItemIDs:
            [UUID] = []

        for reference in
            referenceResult.references
        {
            let filesPayload =
                ClipboardFilesPayload(
                    files: [
                        reference
                    ]
                )

            let duplicateKey =
                filesPayload.duplicateKey

            if let pinnedItem =
                updatedItems.first(
                    where: {
                        $0.kind == .normal &&
                        $0.isPinned &&
                        $0.duplicateKey ==
                            duplicateKey
                    }
                )
            {
                pinnedDuplicateItemIDs.append(
                    pinnedItem.id
                )

                continue
            }

            updatedItems.removeAll {
                $0.kind == .normal &&
                !$0.isPinned &&
                $0.duplicateKey ==
                    duplicateKey
            }

            let newItem =
                ClipboardItem(
                    payload:
                        .files(
                            filesPayload
                        ),
                    createdAt:
                        Date(),
                    sourceAppName:
                        sourceAppName,
                    sourceBundleIdentifier:
                        sourceBundleIdentifier
                )

            newItems.append(
                newItem
            )
        }

        guard
            !newItems.isEmpty
        else {
            if let highlightedItemID =
                pinnedDuplicateItemIDs.last
            {
                signalPinnedDuplicate(
                    itemID:
                        highlightedItemID
                )
            }

            return ClipboardFilesImportResult(
                importedCount: 0,
                pinnedDuplicateCount:
                    pinnedDuplicateItemIDs.count,
                failedFilenames:
                    failedFilenames
            )
        }

        updatedItems.insert(
            contentsOf:
                newItems,
            at: 0
        )

        items =
            retainedItems(
                from:
                    updatedItems
            )

        let retainedItemIDs =
            Set(
                items.map(\.id)
            )

        let survivingImportedCount =
            newItems.filter {
                retainedItemIDs.contains(
                    $0.id
                )
            }
            .count

        finalizeHistoryMutation(
            previousItems:
                previousItems
        )

        if let highlightedItemID =
            pinnedDuplicateItemIDs.last
        {
            signalPinnedDuplicate(
                itemID:
                    highlightedItemID
            )
        }

        return ClipboardFilesImportResult(
            importedCount:
                survivingImportedCount,
            pinnedDuplicateCount:
                pinnedDuplicateItemIDs.count,
            failedFilenames:
                failedFilenames
        )
    }
    
    func copyToClipboard(
        _ item: ClipboardItem
    ) {
        guard item.kind == .normal else {
            return
        }

        filesPasteboardService
            .releasePasteboardAccess()

        mixedFilesPasteboardService
            .releasePasteboardAccess()

        switch item.payload {
        case .text,
             .link:
            let didWrite =
                item.payload
                    .write(
                        to:
                            .general
                    )

            guard didWrite else {
                return
            }

            clipboardMonitoringService
                .synchronizeChangeCount()

            markAsCurrentClipboardItem(
                item
            )


        case let .image(imagePayload):
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                
                do {
                    let didWrite =
                    try await
                    imagePasteboardService
                        .writeImage(
                            imagePayload,
                            customTitle:
                                item.customTitle,
                            to:
                                    .general
                        )
                    
                    guard didWrite else {
                        OperationFailureAlert.show(
                            title:
                                "Image Could Not Be Copied",
                            message:
                                "ClipVault could not write the stored image to the clipboard."
                        )
                        
                        return
                    }
                    
                    clipboardMonitoringService
                        .synchronizeChangeCount()
                    
                    markAsCurrentClipboardItem(
                        item
                    )
                } catch {
                    OperationFailureAlert.show(
                        title:
                            "Image Could Not Be Copied",
                        message:
                            "The stored image could not be loaded.",
                        error: error
                    )
                }
            }
        case let .files(filesPayload):
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                
                do {
                    let didWrite =
                    try await filesPasteboardService
                        .writeFiles(
                            filesPayload,
                            customTitle:
                                item.customTitle,
                            exportIdentifier:
                                item.id,
                            to:
                                    .general
                        )
                    
                    guard didWrite else {
                        OperationFailureAlert.show(
                            title:
                                "File Could Not Be Copied",
                            message:
                                "ClipVault could not write the stored file or folder reference to the clipboard."
                        )
                        
                        return
                    }
                    
                    clipboardMonitoringService
                        .synchronizeChangeCount()
                    
                    markAsCurrentClipboardItem(
                        item
                    )
                } catch {
                    OperationFailureAlert.show(
                        title:
                            "File or Folder Is Unavailable",
                        message:
                            """
                            ClipVault kept the current clipboard unchanged.

                            Restore the original file or folder to an accessible location, then try again.
                            """
                    )
                }
            }
        }
    }
    
    private func markAsCurrentClipboardItem(
        _ item:
            ClipboardItem
    ) {
        markAsCurrentClipboardItems([
            item
        ])
    }

    private func markAsCurrentClipboardItems(
        _ clipboardItems:
            [ClipboardItem]
    ) {
        currentClipboardItemIDs =
            clipboardItems.map(\.id)

        currentClipboardChangeCount =
            NSPasteboard.general
                .changeCount
    }

    private func clearCurrentClipboardItem() {
        currentClipboardItemIDs =
            []

        currentClipboardChangeCount =
            nil
    }

    private func isCurrentClipboardItem(
        _ item:
            ClipboardItem
    ) -> Bool {
        currentClipboardItemIDs
            .contains(
                item.id
            ) &&
        currentClipboardChangeCount ==
            NSPasteboard.general
                .changeCount
    }

    private func currentClipboardItems()
        -> [ClipboardItem]?
    {
        guard
            !currentClipboardItemIDs
                .isEmpty,
            currentClipboardChangeCount ==
                NSPasteboard.general
                    .changeCount
        else {
            return nil
        }

        let itemsByID =
            Dictionary(
                uniqueKeysWithValues:
                    items.map {
                        (
                            $0.id,
                            $0
                        )
                    }
            )

        let clipboardItems =
            currentClipboardItemIDs
                .compactMap {
                    itemsByID[$0]
                }

        guard
            clipboardItems.count ==
                currentClipboardItemIDs
                    .count
        else {
            return nil
        }

        return clipboardItems
    }

    func beginIgnoringClipboardMonitoringChanges() {
        clipboardMonitoringService
            .beginIgnoringClipboardChanges()
    }
    
    func captureAutomatedScreenshot(
        _ imageData:
            Data
    ) {
        guard
            automatedScreenshotCapturePolicyService
                .beginCapture(
                    imageData:
                        imageData,
                    isMonitoringPaused:
                        isMonitoringPaused
                )
        else {
            return
        }

        handleCopiedRasterImage(
            imageData,
            payload:
                ClipboardChangePayload(
                    content:
                        .rasterImage(
                            imageData
                        ),
                    sourceAppName:
                        AutomatedScreenshotCapturePolicyService
                            .sourceAppName,
                    sourceBundleIdentifier:
                        nil,
                    sourceAppPath:
                        nil
                ),
            customTitle:
                AutomatedScreenshotCapturePolicyService
                    .itemTitle,
            completion: {
                [weak self]
                in

                self?
                    .automatedScreenshotCapturePolicyService
                    .finishCapture(
                        imageData:
                            imageData
                    )
            }
        )
    }

    func captureSelectedText(
        _ textPayload:
            ClipboardTextPayload,
        sourceAppName:
            String?,
        sourceBundleIdentifier:
            String?,
        sourceAppPath:
            String?
    ) -> ClipboardCaptureOutcome {
        processClipboardCapture(
            ClipboardChangePayload(
                content:
                    .text(
                        textPayload
                    ),
                sourceAppName:
                    sourceAppName,
                sourceBundleIdentifier:
                    sourceBundleIdentifier,
                sourceAppPath:
                    sourceAppPath
            ),
            captureSource:
                .optionSelect
        )
    }
    
    func endIgnoringClipboardMonitoringChanges() {
        clipboardMonitoringService
            .endIgnoringClipboardChanges()
    }
    
    func pinItem(_ item: ClipboardItem) {
        guard item.kind == .normal else {
            return
        }

        guard
            let index =
                items.firstIndex(
                    where: {
                        $0.id == item.id
                    }
                )
        else {
            return
        }

        guard !items[index].isPinned else {
            return
        }

        var updatedItems = items

        updatedItems[index] =
            updatedItems[index].pinnedCopy()

        items = updatedItems

        saveItems()
    }

    func unpinItem(
        _ item: ClipboardItem
    ) {
        guard
            let index =
                items.firstIndex(
                    where: {
                        $0.id == item.id
                    }
                )
        else {
            return
        }

        guard items[index].isPinned else {
            return
        }

        let previousItems =
            items

        var updatedItems =
            items

        updatedItems[index] =
            updatedItems[index]
                .unpinnedCopy()

        items =
            retainedItems(
                from: updatedItems
            )

        finalizeHistoryMutation(
            previousItems:
                previousItems
        )
    }
    
    func renameItem(
        _ item:
            ClipboardItem,
        customTitle:
            String?
    ) {
        guard
            item.kind == .normal,
            let index =
                items.firstIndex(
                    where: {
                        $0.id ==
                            item.id
                    }
                )
        else {
            return
        }

        let activeClipboardItems =
            currentClipboardItems()

        let wasCurrentClipboardItem =
            activeClipboardItems?
                .contains(
                    where: {
                        $0.id ==
                            item.id
                    }
                ) ==
            true

        let renamedItem =
            items[index]
                .renamedCopy(
                    customTitle:
                        customTitle
                )

        guard
            renamedItem !=
                items[index]
        else {
            return
        }

        var updatedItems =
            items

        updatedItems[index] =
            renamedItem

        items =
            updatedItems

        saveItems()

        guard
            wasCurrentClipboardItem,
            let activeClipboardItems
        else {
            return
        }

        let updatedActiveClipboardItems =
            activeClipboardItems.map {
                activeItem in

                activeItem.id ==
                    renamedItem.id
                    ? renamedItem
                    : activeItem
            }

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            guard
                currentClipboardChangeCount ==
                    NSPasteboard.general
                        .changeCount,
                currentClipboardItemIDs ==
                    updatedActiveClipboardItems
                        .map(\.id)
            else {
                return
            }

            do {
                let imageItems =
                    updatedActiveClipboardItems
                        .filter {
                            $0.imagePayload !=
                                nil
                        }

                let fileItems =
                    updatedActiveClipboardItems
                        .filter {
                            $0.filesPayload !=
                                nil
                        }
                
                let isMixedFinderGroup =
                    !imageItems.isEmpty &&
                    !fileItems.isEmpty &&
                    imageItems.count +
                        fileItems.count ==
                        updatedActiveClipboardItems
                            .count

                let didWrite:
                    Bool

                if imageItems.count ==
                    updatedActiveClipboardItems
                        .count,
                   imageItems.count > 1
                {
                    let entries =
                        imageItems.compactMap {
                            imageItem
                                -> ClipboardImagePasteboardEntry?
                            in

                            guard
                                let imagePayload =
                                    imageItem
                                        .imagePayload
                            else {
                                return nil
                            }

                            return ClipboardImagePasteboardEntry(
                                payload:
                                    imagePayload,
                                customTitle:
                                    imageItem
                                        .customTitle
                            )
                        }

                    guard
                        entries.count ==
                            imageItems.count
                    else {
                        return
                    }

                    didWrite =
                        try await imagePasteboardService
                            .writeImageFiles(
                                entries,
                                to:
                                    .general
                            )
                } else if
                    updatedActiveClipboardItems
                        .count == 1,
                    let imagePayload =
                        renamedItem
                            .imagePayload
                {
                    didWrite =
                        try await imagePasteboardService
                            .writeImage(
                                imagePayload,
                                customTitle:
                                    renamedItem
                                        .customTitle,
                                to:
                                    .general
                            )
                } else if
                    fileItems.count ==
                        updatedActiveClipboardItems
                            .count
                {
                    let entries =
                        fileItems.compactMap {
                            fileItem
                                -> ClipboardFilesPasteboardEntry?
                            in

                            guard
                                let filesPayload =
                                    fileItem
                                        .filesPayload
                            else {
                                return nil
                            }

                            return ClipboardFilesPasteboardEntry(
                                payload:
                                    filesPayload,
                                customTitle:
                                    fileItem
                                        .customTitle,
                                exportIdentifier:
                                    fileItem.id
                            )
                        }

                    guard
                        entries.count ==
                            fileItems.count
                    else {
                        return
                    }

                    didWrite =
                        try await filesPasteboardService
                            .writeFileEntries(
                                entries,
                                to:
                                    .general
                            )
                } else if isMixedFinderGroup {
                    let entries =
                        updatedActiveClipboardItems
                            .compactMap {
                                activeItem
                                    -> ClipboardMixedFilePasteboardEntry?
                                in

                                if let imagePayload =
                                    activeItem.imagePayload
                                {
                                    return .image(
                                        payload:
                                            imagePayload,
                                        customTitle:
                                            activeItem.customTitle
                                    )
                                }

                                if let filesPayload =
                                    activeItem.filesPayload
                                {
                                    return .file(
                                        payload:
                                            filesPayload,
                                        customTitle:
                                            activeItem.customTitle,
                                        exportIdentifier:
                                            activeItem.id
                                    )
                                }

                                return nil
                            }

                    guard
                        entries.count ==
                            updatedActiveClipboardItems
                                .count
                    else {
                        return
                    }

                    didWrite =
                        try await mixedFilesPasteboardService
                            .writeEntries(
                                entries,
                                to:
                                    .general
                            )
                } else {
                    return
                }

                guard didWrite else {
                    return
                }

                clipboardMonitoringService
                    .synchronizeChangeCount()

                markAsCurrentClipboardItems(
                    updatedActiveClipboardItems
                )
            } catch {
                /*
                 The custom title remains saved even when
                 rebuilding the live clipboard fails.
                 */
            }
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        removeItems(
            withIDs: Set([item.id])
        )
    }

    func removeItems(
        withIDs itemIDs: Set<UUID>
    ) {
        guard !itemIDs.isEmpty else {
            return
        }

        let previousItems =
            items

        items.removeAll {
            itemIDs.contains(
                $0.id
            )
        }

        guard
            items.count !=
                previousItems.count
        else {
            return
        }

        finalizeHistoryMutation(
            previousItems:
                previousItems
        )
    }

    func clearHistory() {
        guard !items.isEmpty else {
            return
        }

        let previousItems =
            items

        items.removeAll()

        finalizeHistoryMutation(
            previousItems:
                previousItems
        )
    }
    
    func prepareBackupMerge(
        _ backupItems: [ClipboardItem]
    ) -> ClipboardBackupImportPlan {
        let existingItemByID =
            Dictionary(
                uniqueKeysWithValues:
                    items.map {
                        ($0.id, $0)
                    }
            )

        let preparation =
            ClipboardImportService
                .prepareCompleteMerge(
                    existingItems: items,
                    backupItems: backupItems
                )

        let importedItemIDs =
            Set(
                preparation.preparedItems.compactMap {
                    preparedItem in

                    guard
                        let existingItem =
                            existingItemByID[
                                preparedItem.id
                            ]
                    else {
                        return preparedItem.id
                    }

                    guard
                        preparedItem != existingItem
                    else {
                        return nil
                    }

                    return preparedItem.id
                }
            )

        return ClipboardBackupImportPlan(
            mode: .merge,
            preparedItems:
                preparation.preparedItems,
            importedItemIDs:
                importedItemIDs,
            duplicateCount:
                preparation.duplicateCount,
            requiredUnpinnedItemCount:
                preparation.requiredUnpinnedItemCount
        )
    }

    func prepareBackupReplacement(
        _ backupItems: [ClipboardItem]
    ) -> ClipboardBackupImportPlan {
        let preparation =
            ClipboardImportService
                .prepareCompleteReplacement(
                    backupItems: backupItems
                )

        return ClipboardBackupImportPlan(
            mode: .replace,
            preparedItems:
                preparation.preparedItems,
            importedItemIDs:
                Set(
                    preparation
                        .preparedItems
                        .map(\.id)
                ),
            duplicateCount:
                preparation.duplicateCount,
            requiredUnpinnedItemCount:
                preparation.requiredUnpinnedItemCount
        )
    }
    
    func applyBackupImport(
        plan: ClipboardBackupImportPlan,
        decision: ClipboardImportLimitDecision
    ) -> ClipboardBackupImportApplicationResult {
        let previousHistoryLimit =
            maxItemCount

        let resolution =
            ClipboardImportService
                .resolveHistoryLimit(
                    for: plan.preparedItems,
                    currentHistoryLimit:
                        previousHistoryLimit,
                    maximumHistoryLimit:
                        Self.maximumHistoryLimit,
                    decision: decision
                )

        let resolvedHistoryLimit =
            min(
                max(
                    resolution
                        .resultingHistoryLimit,
                    Self.minimumHistoryLimit
                ),
                Self.maximumHistoryLimit
            )

        maxItemCount =
            resolvedHistoryLimit

        UserDefaults.standard.set(
            resolvedHistoryLimit,
            forKey: maxItemCountKey
        )

        let previousItems =
            items

        items =
            resolution.resolvedItems

        finalizeHistoryMutation(
            previousItems:
                previousItems
        )

        return ClipboardBackupImportApplicationResult(
            mode: plan.mode,
            importedCount:
                importedItemCount(
                    for: plan,
                    resolvedItems:
                        resolution.resolvedItems
                ),
            duplicateCount:
                plan.duplicateCount,
            skippedDueToLimitCount:
                resolution
                    .skippedUnpinnedItemCount,
            resultingHistoryLimit:
                resolvedHistoryLimit,
            didExpandHistoryLimit:
                resolvedHistoryLimit >
                previousHistoryLimit
        )
    }
    
    func setMaxItemCount(
        _ newValue: Int
    ) {
        let clampedValue =
            min(
                max(
                    newValue,
                    Self.minimumHistoryLimit
                ),
                Self.maximumHistoryLimit
            )

        let previousItems =
            items

        maxItemCount =
            clampedValue

        UserDefaults.standard.set(
            clampedValue,
            forKey: maxItemCountKey
        )

        items =
            retainedItems(
                from: items
            )

        finalizeHistoryMutation(
            previousItems:
                previousItems
        )
    }
    
    func setHistoryRetentionOption(
        _ newValue:
            HistoryRetentionOption
    ) {
        let previousItems =
            items

        historyRetentionOption =
            newValue

        UserDefaults.standard.set(
            newValue.rawValue,
            forKey:
                historyRetentionOptionKey
        )

        items =
            retainedItems(
                from: items
            )

        finalizeHistoryMutation(
            previousItems:
                previousItems
        )
    }

    func setShowsSkippedClipWarnings(
        _ newValue:
            Bool
    ) {
        showsSkippedClipWarnings =
            newValue

        UserDefaults
            .standard
            .set(
                newValue,
                forKey:
                    showsSkippedClipWarningsKey
            )
    }

    func setBlocksLikelySensitiveClips(
        _ newValue:
            Bool
    ) {
        blocksLikelySensitiveClips =
            newValue

        UserDefaults
            .standard
            .set(
                newValue,
                forKey:
                    blocksLikelySensitiveClipsKey
            )
    }

    func setBackupKeepCount(
        _ newValue:
            Int
    ) {
        let clampedValue = min(
            max(
                newValue,
                Self.minimumBackupKeepCount
            ),
            Self.maximumBackupKeepCount
        )

        backupKeepCount = clampedValue
        UserDefaults.standard.set(
            clampedValue,
            forKey: backupKeepCountKey
        )
    }
    
    func appRuleMode(for appRule: AppRuleOption) -> AppRuleMode {
        appRuleModes[appRule.id] ?? defaultAppRuleMode(forGroupID: appRule.id)
    }
    
    func setAppRuleMode(_ appRule: AppRuleOption, mode: AppRuleMode) {
        let defaultMode = defaultAppRuleMode(forGroupID: appRule.id)
        
        if mode == defaultMode {
            appRuleModes.removeValue(forKey: appRule.id)
        } else {
            appRuleModes[appRule.id] = mode
        }
        
        saveAppRuleModes()
    }

    func hasCustomAppRuleMode(for appRule: AppRuleOption) -> Bool {
        appRuleModes[appRule.id] != nil
    }

    func resetAppRuleModeToDefault(_ appRule: AppRuleOption) {
        appRuleModes.removeValue(forKey: appRule.id)
        saveAppRuleModes()
    }
    
    func resetAppRuleModesToDefaults() {
        appRuleModes = [:]
        saveAppRuleModes()
    }
    
    func refreshAvailableApps() {
        appDiscoveryTask?.cancel()

        rememberDefaultAppGroups()
        rememberRunningApplications()

        isRefreshingAvailableApps = true

        let discoveryService = appDiscoveryService

        appDiscoveryTask = Task { [weak self] in
            let installedApps = await Task.detached(
                priority: .userInitiated
            ) {
                discoveryService.discoverInstalledApplications()
            }
            .value

            guard !Task.isCancelled else {
                return
            }

            guard let self else {
                return
            }

            self.rememberDiscoveredApps(installedApps)
            self.saveKnownAppRecords()
            self.isRefreshingAvailableApps = false
            self.appDiscoveryTask = nil
        }
    }
    
    private func handleClipboardChange(
        _ payload:
            ClipboardChangePayload
    ) {
        clearCurrentClipboardItem()

        switch payload.content {
        case .text:
            _ =
                processClipboardCapture(
                    payload,
                    captureSource:
                        .nativeClipboard
                )

        case let .fileURLs(fileURLs):
            handleCopiedFileURLs(
                fileURLs,
                payload:
                    payload
            )

        case let .rasterImage(imageData):
            handleCopiedRasterImage(
                imageData,
                payload:
                    payload
            )
        }
    }
    
    private func handleCopiedRasterImage(
        _ imageData:
            Data,
        payload:
            ClipboardChangePayload,
        customTitle:
            String? =
                nil,
        completion:
            @escaping () -> Void =
                {
                }
    ) {
        guard !isMonitoringPaused else {
            completion()

            return
        }

        let sourceAppName =
            payload.sourceAppName

        let sourceBundleIdentifier =
            payload.sourceBundleIdentifier

        if let sourceAppName,
           let sourceBundleIdentifier
        {
            rememberApp(
                displayName:
                    sourceAppName,
                bundleIdentifier:
                    sourceBundleIdentifier,
                appPath:
                    payload.sourceAppPath,
                shouldSave:
                    true
            )
        }

        let sourceRuleMode =
            ruleModeForSourceApp(
                sourceAppName:
                    sourceAppName,
                bundleIdentifier:
                    sourceBundleIdentifier
            )

        guard
            sourceRuleMode !=
                .blocked
        else {
            addBlockedAppSkippedPlaceholder(
                sourceAppName:
                    sourceAppName,
                captureSource:
                    .nativeClipboard
            )

            completion()

            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                completion()

                return
            }

            defer {
                completion()
            }

            do {
                let imagePayload =
                    try await imageStorageService
                        .storeClipboardImage(
                            data:
                                imageData
                        )

                let duplicateKey =
                    imagePayload
                        .duplicateKey

                if let pinnedItem =
                    items.first(
                        where: {
                            $0.kind ==
                                .normal &&
                            $0.isPinned &&
                            $0.duplicateKey ==
                                duplicateKey
                        }
                    )
                {
                    try? await imageStorageService
                        .deleteImage(
                            for:
                                imagePayload
                        )

                    signalPinnedDuplicate(
                        itemID:
                            pinnedItem.id
                    )

                    if let pinnedImagePayload =
                        pinnedItem.imagePayload
                    {
                        let didWrite =
                            try await imagePasteboardService
                                .writeImage(
                                    pinnedImagePayload,
                                    to:
                                        .general
                                )

                        if didWrite {
                            clipboardMonitoringService
                                .synchronizeChangeCount()

                            markAsCurrentClipboardItem(
                                pinnedItem
                            )
                        }
                    }

                    return
                }

                let previousItems =
                    items

                var updatedItems =
                    items

                updatedItems.removeAll {
                    $0.kind ==
                        .normal &&
                    !$0.isPinned &&
                    $0.duplicateKey ==
                        duplicateKey
                }

                let newItem =
                    ClipboardItem(
                        payload:
                            .image(
                                imagePayload
                            ),
                        createdAt:
                            Date(),
                        sourceAppName:
                            sourceAppName,
                        sourceBundleIdentifier:
                            sourceBundleIdentifier,
                        customTitle:
                            customTitle
                    )

                updatedItems.insert(
                    newItem,
                    at:
                        0
                )

                items =
                    retainedItems(
                        from:
                            updatedItems
                    )

                let wasRetained =
                    items.contains {
                        $0.id ==
                            newItem.id
                    }

                finalizeHistoryMutation(
                    previousItems:
                        previousItems
                )

                guard wasRetained else {
                    try? await imageStorageService
                        .deleteImage(
                            for:
                                imagePayload
                        )

                    return
                }

                let didWrite =
                    try await imagePasteboardService
                        .writeImage(
                            imagePayload,
                            to:
                                .general
                        )

                if didWrite {
                    clipboardMonitoringService
                        .synchronizeChangeCount()

                    markAsCurrentClipboardItem(
                        newItem
                    )
                }
            } catch {
                /*
                 Passive clipboard monitoring must not interrupt
                 the user with an alert when image storage or
                 clipboard augmentation fails.
                 */
            }
        }
    }
    
    private func clipboardFinderItems(
        matching fileURLs:
            [URL]
    ) -> [ClipboardItem] {
        var unmatchedItems =
            items.filter {
                $0.kind == .normal &&
                (
                    $0.imagePayload != nil ||
                    $0.filesPayload != nil
                )
            }

        var matchedItems:
            [ClipboardItem] = []

        for fileURL in fileURLs {
            let standardizedPath =
                fileURL
                    .standardizedFileURL
                    .path

            guard
                let matchingIndex =
                    unmatchedItems
                        .firstIndex(
                            where: {
                                clipboardSourcePath(
                                    for:
                                        $0
                                ) ==
                                standardizedPath
                            }
                        )
            else {
                return []
            }

            matchedItems.append(
                unmatchedItems[
                    matchingIndex
                ]
            )

            unmatchedItems.remove(
                at:
                    matchingIndex
            )
        }

        return matchedItems
    }

    private func clipboardSourcePath(
        for item:
            ClipboardItem
    ) -> String? {
        if let originalPath =
            item.imagePayload?
                .originalFileReference?
                .path
        {
            return URL(
                fileURLWithPath:
                    originalPath
            )
            .standardizedFileURL
            .path
        }

        if let fileReference =
            item.filesPayload?
                .files
                .first
        {
            return fileReference
                .fileURL
                .standardizedFileURL
                .path
        }

        return nil
    }
    
    private func clipboardFileItems(
        matching fileURLs:
            [URL]
    ) -> [ClipboardItem] {
        var unmatchedItems =
            items.filter {
                $0.kind == .normal &&
                $0.filesPayload != nil
            }

        var matchedItems:
            [ClipboardItem] = []

        for fileURL in fileURLs {
            let standardizedPath =
                fileURL
                    .standardizedFileURL
                    .path

            guard
                let matchingIndex =
                    unmatchedItems
                        .firstIndex(
                            where: {
                                guard
                                    let fileReference =
                                        $0.filesPayload?
                                            .files
                                            .first
                                else {
                                    return false
                                }

                                return fileReference
                                    .fileURL
                                    .standardizedFileURL
                                    .path ==
                                    standardizedPath
                            }
                        )
            else {
                return []
            }

            matchedItems.append(
                unmatchedItems[
                    matchingIndex
                ]
            )

            unmatchedItems.remove(
                at:
                    matchingIndex
            )
        }

        return matchedItems
    }
    
    private func clipboardImageItems(
        matching fileURLs:
            [URL]
    ) -> [ClipboardItem] {
        var unmatchedItems =
            items.filter {
                $0.kind == .normal &&
                $0.imagePayload != nil
            }

        var matchedItems:
            [ClipboardItem] = []

        for fileURL in fileURLs {
            let standardizedPath =
                fileURL
                    .standardizedFileURL
                    .path

            guard
                let matchingIndex =
                    unmatchedItems
                        .firstIndex(
                            where: {
                                guard
                                    let originalPath =
                                        $0.imagePayload?
                                            .originalFileReference?
                                            .path
                                else {
                                    return false
                                }

                                return URL(
                                    fileURLWithPath:
                                        originalPath
                                )
                                .standardizedFileURL
                                .path ==
                                    standardizedPath
                            }
                        )
            else {
                return []
            }

            matchedItems.append(
                unmatchedItems[
                    matchingIndex
                ]
            )

            unmatchedItems.remove(
                at:
                    matchingIndex
            )
        }

        return matchedItems
    }
    
    private func handleCopiedFileURLs(
        _ fileURLs: [URL],
        payload: ClipboardChangePayload
    ) {
        guard !isMonitoringPaused else {
            return
        }

        let sourceAppName =
            payload.sourceAppName

        let sourceBundleIdentifier =
            payload.sourceBundleIdentifier

        if let sourceAppName,
           let sourceBundleIdentifier
        {
            rememberApp(
                displayName:
                    sourceAppName,
                bundleIdentifier:
                    sourceBundleIdentifier,
                appPath:
                    payload.sourceAppPath,
                shouldSave:
                    true
            )
        }

        let sourceRuleMode =
            ruleModeForSourceApp(
                sourceAppName:
                    sourceAppName,
                bundleIdentifier:
                    sourceBundleIdentifier
            )

        guard
            sourceRuleMode != .blocked
        else {
            addBlockedAppSkippedPlaceholder(
                sourceAppName:
                    sourceAppName,
                captureSource:
                    .nativeClipboard
            )

            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let routingResult =
                ClipboardFileURLRoutingService
                    .route(
                        fileURLs
                    )

            if !routingResult
                .imageFileURLs
                .isEmpty
            {
                _ =
                    await importImageFiles(
                        at:
                            routingResult
                                .imageFileURLs,
                        sourceAppName:
                            sourceAppName ??
                            "Finder",
                        sourceBundleIdentifier:
                            sourceBundleIdentifier
                    )
            }

            if !routingResult
                .fileAndFolderURLs
                .isEmpty
            {
                _ =
                    importFileURLs(
                        routingResult
                            .fileAndFolderURLs,
                        sourceAppName:
                            sourceAppName ??
                            "Finder",
                        sourceBundleIdentifier:
                            sourceBundleIdentifier
                    )
            }

            guard
                routingResult
                    .failedURLs
                    .isEmpty
            else {
                return
            }

            let currentFinderItems =
                clipboardFinderItems(
                    matching:
                        fileURLs
                )

            if currentFinderItems.count ==
                fileURLs.count
            {
                markAsCurrentClipboardItems(
                    currentFinderItems
                )
            }
        }
    }

    @discardableResult
    private func processClipboardCapture(
        _ payload: ClipboardChangePayload,
        captureSource: ClipboardCaptureSource
    ) -> ClipboardCaptureOutcome {
        guard !isMonitoringPaused else {
            return .skippedMonitoringPaused
        }

        guard
            case let .text(
                textPayload
            ) =
                payload.content
        else {
            return .skippedEmpty
        }

        let cleanedText =
            textPayload
                .text
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !cleanedText.isEmpty else {
            return .skippedEmpty
        }
        
        let inferredPayload =
            ClipboardPayload
                .inferred(
                    from:
                        cleanedText,
                    itemKind:
                        .normal
                )

        let capturedPayload:
            ClipboardPayload

        switch inferredPayload {
        case .text:
            capturedPayload =
                .text(
                    ClipboardTextPayload(
                        text:
                            cleanedText,
                        rtfData:
                            textPayload
                                .rtfData,
                        htmlData:
                            textPayload
                                .htmlData
                    )
                )

        case .link,
             .image,
             .files:
            capturedPayload =
                inferredPayload
        }

        let capturedDuplicateKey =
            capturedPayload.duplicateKey

        let sourceAppName =
            payload.sourceAppName

        let sourceBundleIdentifier =
            payload.sourceBundleIdentifier

        if let sourceAppName,
           let sourceBundleIdentifier {
            rememberApp(
                displayName: sourceAppName,
                bundleIdentifier:
                    sourceBundleIdentifier,
                appPath: payload.sourceAppPath,
                shouldSave: true
            )
        }

        let sourceRuleMode =
            ruleModeForSourceApp(
                sourceAppName: sourceAppName,
                bundleIdentifier:
                    sourceBundleIdentifier
            )

        let policyDecision =
            ClipboardCapturePolicyService
                .decision(
                    for:
                        cleanedText,
                    ruleMode:
                        sourceRuleMode,
                    blocksLikelySensitiveClips:
                        blocksLikelySensitiveClips
                )

        switch policyDecision {
        case .capture:
            break

        case .skipBlocked:
            addBlockedAppSkippedPlaceholder(
                sourceAppName: sourceAppName,
                captureSource: captureSource
            )

            return .skippedBlocked

        case .skipSensitive:
            addSensitiveSkippedPlaceholder(
                captureSource: captureSource
            )

            return .skippedSensitive
        }

        if let pinnedItem =
            items.first(
                where: {
                    $0.kind == .normal &&
                        $0.isPinned &&
                        $0.duplicateKey ==
                            capturedDuplicateKey
                }
            )
        {
            signalPinnedDuplicate(
                itemID: pinnedItem.id
            )

            let previousItems =
                items

            items =
                retainedItems(
                    from: items
                )

            finalizeHistoryMutation(
                previousItems:
                    previousItems
            )

            if captureSource ==
                .nativeClipboard
            {
                markAsCurrentClipboardItem(
                    pinnedItem
                )
            }

            return .captured
        }

        let newItem = ClipboardItem(
            payload: capturedPayload,
            createdAt: Date(),
            sourceAppName: sourceAppName,
            sourceBundleIdentifier:
                sourceBundleIdentifier
        )

        let previousItems =
            items

        var updatedItems =
            items

        updatedItems.removeAll {
            $0.kind == .normal &&
                $0.duplicateKey ==
                    capturedDuplicateKey
        }

        updatedItems.insert(
            newItem,
            at: 0
        )

        items =
            retainedItems(
                from: updatedItems
            )

        finalizeHistoryMutation(
            previousItems:
                previousItems
        )

        if captureSource ==
            .nativeClipboard
        {
            markAsCurrentClipboardItem(
                newItem
            )
        }

        return .captured
    }
    
    private func ruleModeForSourceApp(
        sourceAppName: String?,
        bundleIdentifier: String?
    ) -> AppRuleMode {
        guard let bundleIdentifier else {
            return .allowed
        }
        
        let groupID = groupIDForApp(
            displayName: sourceAppName ?? bundleIdentifier,
            bundleIdentifier: bundleIdentifier
        )
        
        return appRuleModes[groupID] ?? defaultAppRuleMode(forGroupID: groupID)
    }
    
    private func defaultAppRuleMode(forGroupID groupID: String) -> AppRuleMode {
        switch groupID {
        case "1password", "bitwarden", "nordpass", "keychain-access":
            return .blocked
        default:
            if groupID.hasPrefix("password-app-") {
                return .blocked
            }
            
            return .allowed
        }
    }
    
    private func signalPinnedDuplicate(
        itemID: UUID
    ) {
        pinnedHighlightTask?.cancel()

        highlightedPinnedItemID = itemID

        pinnedHighlightTask =
            Task { @MainActor [weak self] in
                try? await Task.sleep(
                    for: .milliseconds(900)
                )

                guard !Task.isCancelled else {
                    return
                }

                guard
                    self?.highlightedPinnedItemID ==
                        itemID
                else {
                    return
                }

                self?.highlightedPinnedItemID = nil
            }
    }
    
    private func finalizeHistoryMutation(
        previousItems: [ClipboardItem]
    ) {
        saveItems()

        let imagePayloadsToDelete =
            ClipboardImageAssetCleanupService
                .unreferencedImagePayloads(
                    previousItems:
                        previousItems,
                    remainingItems:
                        items
                )

        guard
            !imagePayloadsToDelete.isEmpty
        else {
            return
        }

        Task {
            for imagePayload in
                imagePayloadsToDelete
            {
                try? await imageStorageService
                    .deleteImage(
                        for: imagePayload
                    )
            }
        }
    }

    private func retainedItems(
        from candidateItems:
            [ClipboardItem]
    ) -> [ClipboardItem] {
        ClipboardRetentionService
            .applyingRules(
                to: candidateItems,
                retentionOption:
                    historyRetentionOption,
                maximumNormalItemCount:
                    maxItemCount
            )
    }
    
    private func importedItemCount(
        for plan: ClipboardBackupImportPlan,
        resolvedItems: [ClipboardItem]
    ) -> Int {
        let resolvedItemIDs =
            Set(
                resolvedItems.map(\.id)
            )

        return plan.importedItemIDs.filter {
            resolvedItemIDs.contains($0)
        }
        .count
    }
    
    private func rememberDefaultAppGroups() {
        for group in defaultAppGroups {
            for bundleIdentifier in group.bundleIdentifiers {
                rememberApp(
                    displayName: group.displayName,
                    bundleIdentifier: bundleIdentifier,
                    appPath: findInstalledAppPath(bundleIdentifier: bundleIdentifier),
                    shouldSave: false
                )
            }
        }
    }
    
    private func rememberRunningApplications() {
        let discoveredApps =
            appDiscoveryService.discoverRunningApplications()

        rememberDiscoveredApps(discoveredApps)
    }
    
    private func findInstalledAppPath(bundleIdentifier: String) -> String? {
        let normalizedBundleIdentifier = bundleIdentifier.lowercased()
        
        if let existingRecord = knownAppRecords[normalizedBundleIdentifier],
           let appPath = existingRecord.appPath {
            return appPath
        }
        
        return nil
    }
    
    private func rememberDiscoveredApps(
        _ discoveredApps: [DiscoveredApp]
    ) {
        for discoveredApp in discoveredApps {
            rememberApp(
                displayName: discoveredApp.displayName,
                bundleIdentifier: discoveredApp.bundleIdentifier,
                appPath: discoveredApp.appPath,
                shouldSave: false
            )
        }
    }
    
    private func rememberApp(
        displayName: String,
        bundleIdentifier: String,
        appPath: String?,
        shouldSave: Bool
    ) {
        let normalizedBundleIdentifier = bundleIdentifier.lowercased()
        let cleanedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalizedBundleIdentifier.isEmpty else {
            return
        }
        
        let finalDisplayName = cleanedDisplayName.isEmpty ? bundleIdentifier : cleanedDisplayName
        
        let record = KnownAppRecord(
            displayName: finalDisplayName,
            bundleIdentifier: normalizedBundleIdentifier,
            appPath: appPath,
            groupID: groupIDForApp(
                displayName: finalDisplayName,
                bundleIdentifier: normalizedBundleIdentifier
            )
        )
        
        knownAppRecords[normalizedBundleIdentifier] = record
        
        if shouldSave {
            saveKnownAppRecords()
        }
    }
    
    private func groupIDForApp(
        displayName: String,
        bundleIdentifier: String
    ) -> String {
        let normalizedBundleIdentifier = bundleIdentifier.lowercased()
        let normalizedDisplayName = displayName.lowercased()
        
        if let defaultGroupID = defaultBundleIdentifierToGroupID[normalizedBundleIdentifier] {
            return defaultGroupID
        }
        
        if normalizedDisplayName.contains("1password") ||
            normalizedBundleIdentifier.contains("1password") ||
            normalizedBundleIdentifier.contains("onepassword") ||
            normalizedBundleIdentifier.contains("agilebits") {
            return "1password"
        }
        
        if normalizedDisplayName.contains("bitwarden") ||
            normalizedBundleIdentifier.contains("bitwarden") {
            return "bitwarden"
        }

        if normalizedDisplayName.contains("nordpass") ||
            normalizedBundleIdentifier.contains("nordpass") {
            return "nordpass"
        }

        if normalizedDisplayName.contains("keychain access") ||
            normalizedBundleIdentifier.contains("keychainaccess") {
            return "keychain-access"
        }

        if normalizedDisplayName.contains("password") {
            return "password-app-\(slugify(displayName))"
        }
        
        if let existingRecord = knownAppRecords[normalizedBundleIdentifier] {
            return existingRecord.groupID
        }
        
        return "app-\(slugify(displayName))"
    }
    
    private func displayNameForGroupID(_ groupID: String) -> String? {
        if let defaultDisplayName = defaultGroupIDToDisplayName[groupID] {
            return defaultDisplayName
        }
        
        return nil
    }
    
    private func slugify(_ value: String) -> String {
        let lowercased = value.lowercased()
        let allowedCharacters = CharacterSet.alphanumerics
        
        var result = ""
        var previousWasDash = false
        
        for scalar in lowercased.unicodeScalars {
            if allowedCharacters.contains(scalar) {
                result.append(String(scalar))
                previousWasDash = false
            } else if !previousWasDash {
                result.append("-")
                previousWasDash = true
            }
        }
        
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    private func saveItems() {
        let itemsToSave = items

        Task {
            do {
                try await ClipboardPersistenceService.shared.saveItems(
                    itemsToSave
                )
            } catch {
                print("Failed to save clipboard history: \(error)")
            }
        }
    }
    
    private func loadItems() {
        do {
            items = try ClipboardPersistenceService.loadItems()

            for item in items {
                if let sourceAppName = item.sourceAppName,
                   let sourceBundleIdentifier = item.sourceBundleIdentifier {
                    rememberApp(
                        displayName: sourceAppName,
                        bundleIdentifier: sourceBundleIdentifier,
                        appPath: nil,
                        shouldSave: false
                    )
                }
            }

            saveKnownAppRecords()

            // Clean up any previously saved placeholder rows.
            saveItems()
        } catch {
            print("Failed to load clipboard history: \(error)")
            items = []
        }
    }
    
    private func loadMaxItemCount() {
        let savedValue = UserDefaults.standard.integer(forKey: maxItemCountKey)
        
        if savedValue == 0 {
            maxItemCount = 100
        } else {
            maxItemCount = min(
                max(
                    savedValue,
                    Self.minimumHistoryLimit
                ),
                Self.maximumHistoryLimit
            )
        }
    }
    
    private func loadHistoryRetentionOption() {
        guard let savedRawValue = UserDefaults.standard.string(forKey: historyRetentionOptionKey),
              let savedOption = HistoryRetentionOption(rawValue: savedRawValue) else {
            historyRetentionOption = .forever
            return
        }
        
        historyRetentionOption = savedOption
    }

    private func loadSkippedClipWarningPreference()
    {
        if UserDefaults
            .standard
            .object(
                forKey:
                    showsSkippedClipWarningsKey
            ) ==
            nil
        {
            showsSkippedClipWarnings =
                true
        } else {
            showsSkippedClipWarnings =
                UserDefaults
                    .standard
                    .bool(
                        forKey:
                            showsSkippedClipWarningsKey
                    )
        }
    }

    private func loadSensitiveClipProtectionPreference()
    {
        if UserDefaults
            .standard
            .object(
                forKey:
                    blocksLikelySensitiveClipsKey
            ) ==
            nil
        {
            /*
             Privacy protection is enabled by default for
             both new users and users upgrading from an
             earlier ClipVault version.
             */
            blocksLikelySensitiveClips =
                true
        } else {
            blocksLikelySensitiveClips =
                UserDefaults
                    .standard
                    .bool(
                        forKey:
                            blocksLikelySensitiveClipsKey
                    )
        }
    }

    private func loadBackupKeepCount()
    {
        let savedValue =
            UserDefaults.standard.integer(
                forKey: backupKeepCountKey
            )

        if savedValue == 0 {
            backupKeepCount = 5
        } else {
            backupKeepCount = min(
                max(
                    savedValue,
                    Self.minimumBackupKeepCount
                ),
                Self.maximumBackupKeepCount
            )
        }
    }
    
    private func loadKnownAppRecords() {
        guard let data = UserDefaults.standard.data(forKey: knownAppRecordsKey) else {
            rememberDefaultAppGroups()
            saveKnownAppRecords()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let savedRecords = try decoder.decode([KnownAppRecord].self, from: data)
            
            knownAppRecords = savedRecords.reduce(into: [:]) { result, record in
                result[record.bundleIdentifier.lowercased()] = record
            }
        } catch {
            print("Failed to load known app records: \(error)")
            knownAppRecords = [:]
        }
        
        rememberDefaultAppGroups()
        saveKnownAppRecords()
    }
    
    private func saveKnownAppRecords() {
        do {
            let encoder = JSONEncoder()
            let records = Array(knownAppRecords.values)
            let data = try encoder.encode(records)
            UserDefaults.standard.set(data, forKey: knownAppRecordsKey)
        } catch {
            print("Failed to save known app records: \(error)")
        }
    }
    
    private func loadAppRuleModes() {
        if let rawDictionary = UserDefaults.standard.dictionary(forKey: appRuleModesKey) as? [String: String] {
            var result: [String: AppRuleMode] = [:]
            
            for entry in rawDictionary {
                if let mode = AppRuleMode(rawValue: entry.value) {
                    let defaultMode = defaultAppRuleMode(forGroupID: entry.key)
                    
                    if mode != defaultMode {
                        result[entry.key] = mode
                    }
                }
            }
            
            appRuleModes = result
            saveAppRuleModes()
            return
        }
        
        appRuleModes = migrateLegacyBlockedAppsToModes().filter { entry in
            entry.value != defaultAppRuleMode(forGroupID: entry.key)
        }
        
        saveAppRuleModes()
    }
    
    private func migrateLegacyBlockedAppsToModes() -> [String: AppRuleMode] {
        var migratedModes: [String: AppRuleMode] = [:]
        
        if let legacyBlockedGroupIDs = UserDefaults.standard.array(forKey: legacyBlockedAppGroupIDsKey) as? [String] {
            for groupID in legacyBlockedGroupIDs {
                migratedModes[groupID] = .blocked
            }
        }
        
        return migratedModes
    }
    
    private func saveAppRuleModes() {
        let rawDictionary = appRuleModes.reduce(into: [String: String]()) { result, entry in
            result[entry.key] = entry.value.rawValue
        }
        
        UserDefaults.standard.set(rawDictionary, forKey: appRuleModesKey)
    }
    
    private func trimItemsToMaxCount() {
        items = ClipboardRetentionService.trimmingNormalItems(
            in: items,
            maximumNormalItemCount: maxItemCount
        )
    }
    
    private func addSensitiveSkippedPlaceholder(
        captureSource: ClipboardCaptureSource
    ) {
        let message: String

        switch captureSource {
        case .nativeClipboard:
            message =
                "(Likely sensitive clip skipped in ClipVault. Clip still available in system clipboard for use.)"

        case .optionSelect:
            message =
                "(Likely sensitive Option-selection skipped in ClipVault. Previous system clipboard restored.)"
        }

        addSkippedPlaceholder(
            message: message
        )
    }
    
    private func addBlockedAppSkippedPlaceholder(
        sourceAppName: String?,
        captureSource: ClipboardCaptureSource
    ) {
        let appName =
            sourceAppName?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let sourceDescription: String

        if let appName, !appName.isEmpty {
            sourceDescription =
                "blocked app: \(appName)"
        } else {
            sourceDescription =
                "a blocked app"
        }

        let message: String

        switch captureSource {
        case .nativeClipboard:
            message =
                "(Clip skipped because it came from \(sourceDescription). Clip still available in system clipboard for use.)"

        case .optionSelect:
            message =
                "(Option-selection skipped because it came from \(sourceDescription). Previous system clipboard restored.)"
        }

        addSkippedPlaceholder(
            message: message
        )
    }
    
    private func addSkippedPlaceholder(message: String) {
        guard showsSkippedClipWarnings else {
            return
        }
        
        let placeholder = ClipboardItem(
            text: message,
            createdAt: Date(),
            kind: .sensitiveSkipped
        )

        items.insert(placeholder, at: 0)
        trimItemsToMaxCount()

        // Do not call saveItems().
        // This keeps warning rows visible during the current session
        // without storing placeholders permanently.
    }
}
