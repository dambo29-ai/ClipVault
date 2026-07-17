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
    @Published private(set) var showsSkippedClipWarnings: Bool = true
    @Published private(set) var backupKeepCount: Int = 5
    @Published private(set) var knownAppRecords: [String: KnownAppRecord] = [:]
    @Published private(set) var appRuleModes: [String: AppRuleMode] = [:]
    @Published private(set) var isRefreshingAvailableApps = false
    @Published private(set) var highlightedPinnedItemID: UUID?
    
    private let maxItemCountKey = "maxItemCount"
    private let historyRetentionOptionKey = "historyRetentionOption"
    private let showsSkippedClipWarningsKey = "showsSkippedClipWarnings"
    private let backupKeepCountKey = "backupKeepCount"
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

    private var appDiscoveryTask: Task<Void, Never>?
    private var pinnedHighlightTask: Task<Void, Never>?
    
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
                .shared
    ) {
        self.imageStorageService =
            imageStorageService

        imagePasteboardService =
            ClipboardImagePasteboardService(
                imageStorageService:
                    imageStorageService
            )

        loadMaxItemCount()
        loadHistoryRetentionOption()
        loadSkippedClipWarningPreference()
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
                let imagePayload =
                    try await imageStorageService
                        .storeImage(
                            at: fileURL
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
    
    func copyToClipboard(
        _ item: ClipboardItem
    ) {
        guard item.kind == .normal else {
            return
        }

        switch item.payload {
        case .text, .link:
            let didWrite =
                item.payload.write(
                    to: .general
                )

            guard didWrite else {
                return
            }

            clipboardMonitoringService
                .synchronizeChangeCount()

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
                                    to: .general
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
        }
    }

    func beginIgnoringClipboardMonitoringChanges() {
        clipboardMonitoringService
            .beginIgnoringClipboardChanges()
    }

    func captureSelectedText(
        _ text: String,
        sourceAppName: String?,
        sourceBundleIdentifier: String?,
        sourceAppPath: String?
    ) -> ClipboardCaptureOutcome {
        processClipboardCapture(
            ClipboardChangePayload(
                content:
                    .text(text),
                sourceAppName:
                    sourceAppName,
                sourceBundleIdentifier:
                    sourceBundleIdentifier,
                sourceAppPath:
                    sourceAppPath
            ),
            captureSource: .optionSelect
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
    
    func importNormalItemsFromBackup(
        _ backupItems: [ClipboardItem]
    ) -> ClipboardBackupImportOutcome {
        let preparation =
            ClipboardImportService.prepareImport(
                existingItems: items,
                backupItems: backupItems,
                maximumItemCount: maxItemCount
            )

        if preparation.skippedDueToLimitCount > 0 {
            return .exceedsHistoryLimit(
                itemsOverLimit:
                    preparation.skippedDueToLimitCount
            )
        }

        if preparation.importedCount > 0 {
            let previousItems =
                items

            items =
                preparation.mergedItems

            finalizeHistoryMutation(
                previousItems:
                    previousItems
            )
        }

        return .imported(
            importedCount: preparation.importedCount,
            duplicateCount: preparation.duplicateCount
        )
    }
    
    func replaceHistoryWithBackupItems(
        _ backupItems: [ClipboardItem]
    ) -> ClipboardBackupReplacementResult {
        let preparation =
            ClipboardImportService.prepareReplacement(
                backupItems: backupItems,
                maximumItemCount: maxItemCount
            )

        let previousItems =
            items

        items =
            preparation.replacementItems

        finalizeHistoryMutation(
            previousItems:
                previousItems
        )

        return ClipboardBackupReplacementResult(
            imported: preparation.replacementItems.count,
            duplicates: preparation.duplicateCount,
            skippedDueToLimit:
                preparation.skippedDueToLimitCount
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

    func setShowsSkippedClipWarnings(_ newValue: Bool) {
        showsSkippedClipWarnings = newValue
        UserDefaults.standard.set(newValue, forKey: showsSkippedClipWarningsKey)
    }

    func setBackupKeepCount(_ newValue: Int) {
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
        _ payload: ClipboardChangePayload
    ) {
        switch payload.content {
        case .text:
            _ = processClipboardCapture(
                payload,
                captureSource:
                    .nativeClipboard
            )

        case let .fileURLs(fileURLs):
            handleCopiedFileURLs(
                fileURLs,
                payload: payload
            )
        }
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

            _ =
                await importImageFiles(
                    at: fileURLs,
                    sourceAppName:
                        sourceAppName ??
                        "Finder",
                    sourceBundleIdentifier:
                        sourceBundleIdentifier
                )
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
            case let .text(text) =
                payload.content
        else {
            return .skippedEmpty
        }

        let cleanedText =
            text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanedText.isEmpty else {
            return .skippedEmpty
        }
        
        let capturedPayload =
            ClipboardPayload.inferred(
                from: cleanedText,
                itemKind: .normal
            )

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
            ClipboardCapturePolicyService.decision(
                for: cleanedText,
                ruleMode: sourceRuleMode
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

    private func loadSkippedClipWarningPreference() {
        if UserDefaults.standard.object(forKey: showsSkippedClipWarningsKey) == nil {
            showsSkippedClipWarnings = true
        } else {
            showsSkippedClipWarnings = UserDefaults.standard.bool(forKey: showsSkippedClipWarningsKey)
        }
    }

    private func loadBackupKeepCount() {
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
