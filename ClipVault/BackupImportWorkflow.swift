//
//  BackupImportWorkflow.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/11/26.
//

import AppKit

enum BackupImportWorkflow {
    @MainActor
    static func handle(
        backupItems: [ClipboardItem],
        clipboardStore: ClipboardStore,
        openSettings: () -> Void
    ) {
        let outcome =
            clipboardStore.importNormalItemsFromBackup(
                backupItems
            )

        switch outcome {
        case .imported(
            let importedCount,
            let duplicateCount
        ):
            BackupImportSuccessAlert.show(
                importedCount: importedCount,
                duplicateCount: duplicateCount,
                skippedDueToLimitCount: 0,
                replacedHistory: false
            )

        case .exceedsHistoryLimit(let itemsOverLimit):
            let currentHistoryLimit =
                clipboardStore.maxItemCount

            let requiredHistoryLimit =
                currentHistoryLimit + itemsOverLimit

            let choice = BackupImportLimitConfirmation.show(
                itemsOverLimit: itemsOverLimit,
                historyLimit: currentHistoryLimit,
                requiredHistoryLimit:
                    requiredHistoryLimit,
                maximumAllowedHistoryLimit:
                    ClipboardStore.maximumHistoryLimit
            )

            switch choice {
            case .replace:
                let replacementResult =
                    clipboardStore
                        .replaceHistoryWithBackupItems(
                            backupItems
                        )

                BackupImportSuccessAlert.show(
                    importedCount:
                        replacementResult.imported,
                    duplicateCount:
                        replacementResult.duplicates,
                    skippedDueToLimitCount:
                        replacementResult.skippedDueToLimit,
                    replacedHistory: true
                )

            case .openSettings:
                openSettings()

                NSApplication.shared.activate(
                    ignoringOtherApps: true
                )

                showOpenSettingsInstructions(
                    currentHistoryLimit:
                        currentHistoryLimit,
                    requiredHistoryLimit:
                        requiredHistoryLimit
                )

            case .cancel:
                return
            }
        }
    }

    @MainActor
    private static func showOpenSettingsInstructions(
        currentHistoryLimit: Int,
        requiredHistoryLimit: Int
    ) {
        let alert = NSAlert()

        alert.messageText =
            "Increase the History Limit"

        alert.informativeText =
            """
            The backup has not been imported.

            Increase the History Limit from \(currentHistoryLimit) to at least \(requiredHistoryLimit), then run the import again.
            """

        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
