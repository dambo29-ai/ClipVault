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
        replacedHistory: Bool
    ) {
        let alert = NSAlert()

        let importedWord =
            importedCount == 1 ? "clip" : "clips"

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
            alert.messageText = "Backup Imported"

            messageLines.append(
                "Replaced the current clipboard history with \(importedCount) \(importedWord)."
            )

            if duplicateCount > 0 {
                messageLines.append(
                    "Skipped \(duplicateCount) \(duplicateWord) found within the backup."
                )
            }

            if skippedDueToLimitCount > 0 {
                messageLines.append(
                    "Omitted \(skippedDueToLimitCount) \(limitWord) because of the current History Limit."
                )
            }
        } else if importedCount == 0 {
            alert.messageText = "No New Clips Imported"

            messageLines.append(
                "The backup did not contain any new clips."
            )

            if duplicateCount > 0 {
                messageLines.append(
                    "Skipped \(duplicateCount) \(duplicateWord)."
                )
            }
        } else {
            alert.messageText = "Backup Imported"

            messageLines.append(
                "Imported \(importedCount) new \(importedWord)."
            )

            if duplicateCount > 0 {
                messageLines.append(
                    "Skipped \(duplicateCount) \(duplicateWord)."
                )
            }
        }

        alert.informativeText =
            messageLines.joined(separator: "\n")

        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
