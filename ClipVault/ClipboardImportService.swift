//
//  ClipboardImportService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/11/26.
//

import Foundation

enum ClipboardImportService {
    static func itemsFromLatestJSONBackup() throws -> [ClipboardItem] {
        let backupURL = try ClipboardHistoryExportService.latestJSONBackupURL()

        return try itemsFromJSONBackup(
            at: backupURL
        )
    }

    static func itemsFromJSONBackup(
        at backupURL: URL
    ) throws -> [ClipboardItem] {
        guard backupURL.pathExtension.lowercased() == "json" else {
            throw ClipboardImportError.invalidFileType
        }

        let didStartAccessing =
            backupURL.startAccessingSecurityScopedResource()

        defer {
            if didStartAccessing {
                backupURL.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(
            contentsOf: backupURL
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup: ClipboardHistoryBackup

        do {
            backup = try decoder.decode(
                ClipboardHistoryBackup.self,
                from: data
            )
        } catch {
            throw ClipboardImportError.invalidClipVaultBackup
        }

        guard backup.appName == "ClipVault" else {
            throw ClipboardHistoryExportError.invalidBackupAppName
        }

        guard backup.formatVersion == 1 else {
            throw ClipboardHistoryExportError.unsupportedBackupFormat
        }

        return backup.items.filter {
            $0.kind == .normal
        }
    }

    static func prepareImport(
        existingItems: [ClipboardItem],
        backupItems: [ClipboardItem],
        maximumItemCount: Int
    ) -> ClipboardImportPreparation {
        let existingKeys = Set(
            existingItems
                .filter { $0.kind == .normal }
                .map(\.duplicateKey)
        )

        var importedItems: [ClipboardItem] = []
        var duplicateCount = 0
        var seenBackupKeys = Set<String>()

        for item in backupItems where item.kind == .normal {
            let key = item.duplicateKey

            if existingKeys.contains(key) ||
                seenBackupKeys.contains(key) {
                duplicateCount += 1
            } else {
                importedItems.append(
                    item.restoredCopy()
                )

                seenBackupKeys.insert(key)
            }
        }

        guard !importedItems.isEmpty else {
            return ClipboardImportPreparation(
                mergedItems: existingItems,
                importedCount: 0,
                duplicateCount: duplicateCount,
                skippedDueToLimitCount: 0
            )
        }

        var mergedItems = existingItems
        mergedItems.append(contentsOf: importedItems)

        mergedItems.sort {
            $0.createdAt > $1.createdAt
        }

        let mergedNormalItemCount = mergedItems.filter {
            $0.kind == .normal
        }.count

        let itemsOverLimit = max(
            0,
            mergedNormalItemCount - maximumItemCount
        )

        if itemsOverLimit > 0 {
            return ClipboardImportPreparation(
                mergedItems: existingItems,
                importedCount: 0,
                duplicateCount: duplicateCount,
                skippedDueToLimitCount: itemsOverLimit
            )
        }

        return ClipboardImportPreparation(
            mergedItems: mergedItems,
            importedCount: importedItems.count,
            duplicateCount: duplicateCount,
            skippedDueToLimitCount: 0
        )
    }

    static func prepareReplacement(
        backupItems: [ClipboardItem],
        maximumItemCount: Int
    ) -> ClipboardReplacementPreparation {
        var replacementItems: [ClipboardItem] = []
        var seenKeys = Set<String>()
        var duplicateCount = 0

        for item in backupItems where item.kind == .normal {
            let key = item.duplicateKey

            if seenKeys.contains(key) {
                duplicateCount += 1
            } else {
                replacementItems.append(
                    item.restoredCopy()
                )

                seenKeys.insert(key)
            }
        }

        replacementItems.sort {
            $0.createdAt > $1.createdAt
        }

        let skippedDueToLimitCount = max(
            0,
            replacementItems.count - maximumItemCount
        )

        if skippedDueToLimitCount > 0 {
            replacementItems = Array(
                replacementItems.prefix(maximumItemCount)
            )
        }

        return ClipboardReplacementPreparation(
            replacementItems: replacementItems,
            duplicateCount: duplicateCount,
            skippedDueToLimitCount: skippedDueToLimitCount
        )
    }
    
    static func prepareCompleteMerge(
        existingItems: [ClipboardItem],
        backupItems: [ClipboardItem]
    ) -> ClipboardCompleteImportPreparation {
        var preparedItems = existingItems
        var itemIndexByKey: [String: Int] = [:]

        for (index, item) in
            preparedItems.enumerated()
        where item.kind == .normal {
            itemIndexByKey[
                item.duplicateKey
            ] = index
        }

        var importedCount = 0
        var duplicateCount = 0

        for backupItem in backupItems
        where backupItem.kind == .normal {
            let restoredItem =
                backupItem.restoredCopy()

            let key =
                restoredItem.duplicateKey

            if let existingIndex =
                itemIndexByKey[key]
            {
                let existingItem =
                    preparedItems[existingIndex]

                if restoredItem.isPinned &&
                    !existingItem.isPinned
                {
                    preparedItems[existingIndex] =
                        restoredItem

                    importedCount += 1
                } else {
                    duplicateCount += 1
                }

                continue
            }

            preparedItems.append(
                restoredItem
            )

            itemIndexByKey[key] =
                preparedItems.count - 1

            importedCount += 1
        }

        preparedItems.sort {
            $0.createdAt > $1.createdAt
        }

        return ClipboardCompleteImportPreparation(
            preparedItems: preparedItems,
            importedCount: importedCount,
            duplicateCount: duplicateCount,
            requiredUnpinnedItemCount:
                requiredUnpinnedItemCount(
                    in: preparedItems
                )
        )
    }

    static func prepareCompleteReplacement(
        backupItems: [ClipboardItem]
    ) -> ClipboardCompleteReplacementPreparation {
        var preparedItems: [ClipboardItem] = []
        var itemIndexByKey: [String: Int] = [:]
        var duplicateCount = 0

        for backupItem in backupItems
        where backupItem.kind == .normal {
            let restoredItem =
                backupItem.restoredCopy()

            let key =
                restoredItem.duplicateKey

            if let existingIndex =
                itemIndexByKey[key]
            {
                let existingItem =
                    preparedItems[existingIndex]

                if restoredItem.isPinned &&
                    !existingItem.isPinned
                {
                    preparedItems[existingIndex] =
                        restoredItem
                } else {
                    duplicateCount += 1
                }

                continue
            }

            preparedItems.append(
                restoredItem
            )

            itemIndexByKey[key] =
                preparedItems.count - 1
        }

        preparedItems.sort {
            $0.createdAt > $1.createdAt
        }

        return ClipboardCompleteReplacementPreparation(
            preparedItems: preparedItems,
            duplicateCount: duplicateCount,
            requiredUnpinnedItemCount:
                requiredUnpinnedItemCount(
                    in: preparedItems
                )
        )
    }
    
    static func resolveHistoryLimit(
        for preparedItems: [ClipboardItem],
        currentHistoryLimit: Int,
        maximumHistoryLimit: Int,
        decision: ClipboardImportLimitDecision
    ) -> ClipboardImportLimitResolution {
        let safeCurrentLimit =
            max(
                0,
                currentHistoryLimit
            )

        let safeMaximumLimit =
            max(
                safeCurrentLimit,
                maximumHistoryLimit
            )

        let requiredItemCount =
            requiredUnpinnedItemCount(
                in: preparedItems
            )

        switch decision {
        case .keepLimit:
            let resolvedItems =
                applyingHistoryLimit(
                    to: preparedItems,
                    maximumUnpinnedItemCount:
                        safeCurrentLimit
                )

            return ClipboardImportLimitResolution(
                resolvedItems: resolvedItems,
                resultingHistoryLimit:
                    safeCurrentLimit,
                skippedUnpinnedItemCount:
                    max(
                        0,
                        requiredItemCount -
                        safeCurrentLimit
                    ),
                didExpandHistoryLimit: false
            )

        case .expandLimit:
            let roundedRequiredLimit =
                roundedHistoryLimit(
                    requiredItemCount:
                        requiredItemCount
                )

            let resultingHistoryLimit =
                min(
                    max(
                        safeCurrentLimit,
                        roundedRequiredLimit
                    ),
                    safeMaximumLimit
                )

            let resolvedItems =
                applyingHistoryLimit(
                    to: preparedItems,
                    maximumUnpinnedItemCount:
                        resultingHistoryLimit
                )

            return ClipboardImportLimitResolution(
                resolvedItems: resolvedItems,
                resultingHistoryLimit:
                    resultingHistoryLimit,
                skippedUnpinnedItemCount:
                    max(
                        0,
                        requiredItemCount -
                        resultingHistoryLimit
                    ),
                didExpandHistoryLimit:
                    resultingHistoryLimit >
                    safeCurrentLimit
            )
        }
    }
    
    static func requiredUnpinnedItemCount(
        in items: [ClipboardItem]
    ) -> Int {
        items.filter {
            $0.kind == .normal &&
            !$0.isPinned
        }
        .count
    }

    static func roundedHistoryLimit(
        requiredItemCount: Int,
        increment: Int = 10
    ) -> Int {
        guard requiredItemCount > 0 else {
            return 0
        }

        let safeIncrement = max(
            1,
            increment
        )

        let quotient =
            requiredItemCount /
            safeIncrement

        let remainder =
            requiredItemCount %
            safeIncrement

        if remainder == 0 {
            return requiredItemCount
        }

        return
            (quotient + 1) *
            safeIncrement
    }

    static func applyingHistoryLimit(
        to items: [ClipboardItem],
        maximumUnpinnedItemCount: Int
    ) -> [ClipboardItem] {
        var remainingUnpinnedSlots =
            max(
                0,
                maximumUnpinnedItemCount
            )

        return items.filter {
            item in

            guard item.kind == .normal else {
                return true
            }

            if item.isPinned {
                return true
            }

            guard remainingUnpinnedSlots > 0 else {
                return false
            }

            remainingUnpinnedSlots -= 1
            return true
        }
    }
}

enum ClipboardImportError: LocalizedError, Equatable {
    case invalidFileType
    case invalidClipVaultBackup

    var errorDescription: String? {
        switch self {
        case .invalidFileType:
            return "Please select a ClipVault JSON backup file."

        case .invalidClipVaultBackup:
            return "This JSON file is not a valid ClipVault backup."
        }
    }
}

enum ClipboardImportLimitDecision:
    Equatable,
    Sendable
{
    case keepLimit
    case expandLimit
}

struct ClipboardImportLimitResolution:
    Equatable,
    Sendable
{
    let resolvedItems: [ClipboardItem]
    let resultingHistoryLimit: Int
    let skippedUnpinnedItemCount: Int
    let didExpandHistoryLimit: Bool
}

struct ClipboardCompleteImportPreparation {
    let preparedItems: [ClipboardItem]
    let importedCount: Int
    let duplicateCount: Int
    let requiredUnpinnedItemCount: Int
}

struct ClipboardCompleteReplacementPreparation {
    let preparedItems: [ClipboardItem]
    let duplicateCount: Int
    let requiredUnpinnedItemCount: Int
}

struct ClipboardImportPreparation {
    let mergedItems: [ClipboardItem]
    let importedCount: Int
    let duplicateCount: Int
    let skippedDueToLimitCount: Int
}

struct ClipboardReplacementPreparation {
    let replacementItems: [ClipboardItem]
    let duplicateCount: Int
    let skippedDueToLimitCount: Int
}
