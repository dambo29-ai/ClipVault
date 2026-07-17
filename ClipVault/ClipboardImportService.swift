//
//  ClipboardImportService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/11/26.
//

import Foundation

enum ClipboardImportService {
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

