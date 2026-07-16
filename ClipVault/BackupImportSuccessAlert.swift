//
//  BackupImportSuccessAlert.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/11/26.
//

import AppKit

enum BackupImportSuccessAlert {
    @MainActor
    static func show(
        importedCount: Int,
        duplicateCount: Int,
        skippedDueToLimitCount: Int,
        replacedHistory: Bool,
        resultingHistoryLimit: Int? = nil,
        didExpandHistoryLimit: Bool = false
    ) {
        let alert = NSAlert()

        let importedWord =
            importedCount == 1
                ? "clip"
                : "clips"

        let duplicateWord =
            duplicateCount == 1
                ? "duplicate clip"
                : "duplicate clips"

        let limitWord =
            skippedDueToLimitCount == 1
                ? "clip"
                : "clips"

        var messageLines: [String] = []

        if replacedHistory {
            alert.messageText =
                "Backup Imported"

            messageLines.append(
                "Replaced the current clipboard history with \(importedCount) \(importedWord)."
            )
        } else if importedCount == 0 {
            alert.messageText =
                "No New Clips Imported"

            messageLines.append(
                "The backup did not contain any new clips."
            )
        } else {
            alert.messageText =
                "Backup Imported"

            messageLines.append(
                "Imported \(importedCount) new \(importedWord)."
            )
        }

        if duplicateCount > 0 {
            messageLines.append(
                "Skipped \(duplicateCount) \(duplicateWord)."
            )
        }

        if skippedDueToLimitCount > 0 {
            messageLines.append(
                "Omitted \(skippedDueToLimitCount) of the oldest unpinned \(limitWord) because of the History Limit."
            )
        }

        if didExpandHistoryLimit,
           let resultingHistoryLimit
        {
            messageLines.append(
                "The History Limit was increased to \(resultingHistoryLimit)."
            )
        }

        alert.informativeText =
            messageLines.joined(
                separator: "\n"
            )

        alert.alertStyle =
            .informational

        alert.addButton(
            withTitle: "OK"
        )

        alert.runModal()
    }
}
