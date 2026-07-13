//
//  BackupImportLimitConfirmation.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/11/26.
//

import AppKit

enum BackupImportLimitChoice {
    case replace
    case openSettings
    case cancel
}

enum BackupImportLimitConfirmation {
    @MainActor
    static func show(
        itemsOverLimit: Int,
        historyLimit: Int,
        requiredHistoryLimit: Int,
        maximumAllowedHistoryLimit: Int
    ) -> BackupImportLimitChoice {
        let alert = NSAlert()

        alert.alertStyle = .warning
        alert.messageText =
            "The backup does not fit in the current history limit."

        let clipWord =
            itemsOverLimit == 1 ? "clip" : "clips"

        if requiredHistoryLimit <= maximumAllowedHistoryLimit {
            alert.informativeText =
                """
                Importing this backup would exceed the current History Limit of \(historyLimit) by \(itemsOverLimit) \(clipWord).

                Replace the current clipboard history with the backup, or open Settings and increase the History Limit to at least \(requiredHistoryLimit).
                """

            let openSettingsButton = alert.addButton(
                withTitle: "Open Settings"
            )
            openSettingsButton.keyEquivalent = "\r"

            alert.addButton(
                withTitle: "Replace"
            )

            let response = alert.runModal()

            if response == .alertSecondButtonReturn {
                return .replace
            }

            return .openSettings
        }

        alert.informativeText =
            """
            Importing this backup would require a History Limit of \(requiredHistoryLimit), but ClipVault allows a maximum of \(maximumAllowedHistoryLimit).

            Replace the current clipboard history with the newest \(maximumAllowedHistoryLimit) clips from the backup, or cancel the import.
            """

        let cancelButton = alert.addButton(
            withTitle: "Cancel"
        )
        cancelButton.keyEquivalent = "\r"

        alert.addButton(
            withTitle: "Replace"
        )

        let response = alert.runModal()

        if response == .alertSecondButtonReturn {
            return .replace
        }

        return .cancel
    }
}
