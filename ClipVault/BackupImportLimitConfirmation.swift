//
//  BackupImportLimitConfirmation.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/11/26.
//

import AppKit

enum BackupImportLimitChoice {
    case expandLimit
    case keepLimit
    case cancel
}

enum BackupImportLimitConfirmation {
    @MainActor
    static func show(
        currentHistoryLimit: Int,
        requiredHistoryLimit: Int,
        expandedHistoryLimit: Int,
        maximumAllowedHistoryLimit: Int
    ) -> BackupImportLimitChoice {
        let alert = NSAlert()

        alert.alertStyle = .warning
        alert.messageText =
            "This backup exceeds the current History Limit."

        let itemsOverLimit =
            max(
                0,
                requiredHistoryLimit -
                currentHistoryLimit
            )

        let omittedWord =
            itemsOverLimit == 1
                ? "clip"
                : "clips"

        if requiredHistoryLimit <=
            maximumAllowedHistoryLimit
        {
            alert.informativeText =
                """
                The imported history requires space for \(requiredHistoryLimit) unpinned clips, but your current History Limit is \(currentHistoryLimit).

                Expand the History Limit to \(expandedHistoryLimit) to restore everything, or keep the current limit and omit the \(itemsOverLimit) oldest unpinned \(omittedWord).

                Pinned clips will be restored either way and do not count toward the History Limit.
                """

            let expandButton =
                alert.addButton(
                    withTitle:
                        "Expand Limit to \(expandedHistoryLimit)"
                )

            expandButton.keyEquivalent = "\r"

            alert.addButton(
                withTitle:
                    "Keep Limit at \(currentHistoryLimit)"
            )

            alert.addButton(
                withTitle: "Cancel"
            )

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                return .expandLimit

            case .alertSecondButtonReturn:
                return .keepLimit

            default:
                return .cancel
            }
        }

        let maximumOmittedCount =
            max(
                0,
                requiredHistoryLimit -
                maximumAllowedHistoryLimit
            )

        let maximumOmittedWord =
            maximumOmittedCount == 1
                ? "clip"
                : "clips"

        alert.informativeText =
            """
            The imported history requires space for \(requiredHistoryLimit) unpinned clips, but ClipVault allows a maximum History Limit of \(maximumAllowedHistoryLimit).

            Continue with the maximum limit and omit the \(maximumOmittedCount) oldest unpinned \(maximumOmittedWord), or cancel the import.

            Pinned clips will still be restored and do not count toward the History Limit.
            """

        let keepButton =
            alert.addButton(
                withTitle:
                    "Use Maximum Limit of \(maximumAllowedHistoryLimit)"
            )

        keepButton.keyEquivalent = "\r"

        alert.addButton(
            withTitle: "Cancel"
        )

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .expandLimit

        default:
            return .cancel
        }
    }
}
