//
//  ClipboardRetentionService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/13/26.
//

import Foundation

enum ClipboardRetentionService {
    static func applyingRules(
        to items: [ClipboardItem],
        retentionOption: HistoryRetentionOption,
        maximumNormalItemCount: Int,
        now: Date = Date()
    ) -> [ClipboardItem] {
        let itemsAfterExpiration = removingExpiredItems(
            from: items,
            retentionOption: retentionOption,
            now: now
        )

        return trimmingNormalItems(
            in: itemsAfterExpiration,
            maximumNormalItemCount: maximumNormalItemCount
        )
    }

    static func removingExpiredItems(
        from items: [ClipboardItem],
        retentionOption: HistoryRetentionOption,
        now: Date = Date()
    ) -> [ClipboardItem] {
        guard let retentionInterval =
            retentionOption.retentionInterval else {
            return items
        }

        let cutoffDate = now.addingTimeInterval(
            -retentionInterval
        )

        return items.filter { item in
            guard item.kind == .normal else {
                return true
            }

            if item.isPinned {
                return true
            }

            if item.origin == .restored {
                return true
            }

            return item.createdAt >= cutoffDate
        }
    }

    static func trimmingNormalItems(
        in items: [ClipboardItem],
        maximumNormalItemCount: Int
    ) -> [ClipboardItem] {
        var remainingNormalItemSlots = max(
            0,
            maximumNormalItemCount
        )

        return items.filter { item in
            guard item.kind == .normal else {
                return true
            }

            if item.isPinned {
                return true
            }

            guard remainingNormalItemSlots > 0 else {
                return false
            }

            remainingNormalItemSlots -= 1
            return true
        }
    }
}

