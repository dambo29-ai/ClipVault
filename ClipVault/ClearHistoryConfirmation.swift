//
//  ClearHistoryConfirmation.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/9/26.
//

import AppKit

enum ClipboardClearMode {
    case unpinned
    case includingPinned
}

struct ClipboardClearConfirmationDescriptor {
    let menuTitle: String
    let alertTitle: String
    let informativeText: String
    let actionButtonTitle: String
}

enum ClearHistoryConfirmation {
    @MainActor
    static func shouldClearHistory() -> Bool {
        let descriptor =
            ClipboardClearConfirmationDescriptor(
                menuTitle: "Clear All History…",
                alertTitle:
                    "Clear All Clipboard History?",
                informativeText:
                    """
                    This will permanently remove all \
                    clipboard history, including pinned \
                    items.
                    """,
                actionButtonTitle:
                    "Clear Everything"
            )

        return shouldClear(
            descriptor: descriptor
        )
    }
    @MainActor
    static func shouldClear(
        descriptor:
            ClipboardClearConfirmationDescriptor
    ) -> Bool {
        let alert = NSAlert()

        alert.messageText =
            descriptor.alertTitle

        alert.informativeText =
            descriptor.informativeText

        alert.alertStyle = .warning

        let clearButton =
            alert.addButton(
                withTitle:
                    descriptor.actionButtonTitle
            )

        clearButton.keyEquivalent = "\r"

        let cancelButton =
            alert.addButton(
                withTitle: "Cancel"
            )

        cancelButton.keyEquivalent = "\u{1b}"

        let response = alert.runModal()

        return response ==
            .alertFirstButtonReturn
    }

    static func descriptor(
        for result: ClipboardClearScopeResult,
        contentScope: ClipboardClearContentScope,
        hasActiveSearch: Bool,
        mode: ClipboardClearMode
    ) -> ClipboardClearConfirmationDescriptor {
        let normalItemCount: Int

        switch mode {
        case .unpinned:
            normalItemCount =
                result.unpinnedNormalItemCount

        case .includingPinned:
            normalItemCount =
                result.normalItemCount
        }

        if normalItemCount == 0 &&
            result.warningCount > 0
        {
            return warningOnlyDescriptor(
                warningCount: result.warningCount,
                hasActiveSearch: hasActiveSearch
            )
        }

        let scopeDescription =
            description(
                for: contentScope,
                count: normalItemCount
            )

        let warningSentence =
            additionalWarningSentence(
                warningCount: result.warningCount
            )

        switch mode {
        case .unpinned:
            return ClipboardClearConfirmationDescriptor(
                menuTitle:
                    unpinnedMenuTitle(
                        contentScope: contentScope,
                        hasActiveSearch:
                            hasActiveSearch
                    ),
                alertTitle:
                    unpinnedAlertTitle(
                        contentScope: contentScope,
                        count: normalItemCount,
                        hasActiveSearch:
                            hasActiveSearch
                    ),
                informativeText:
                    unpinnedInformativeText(
                        scopeDescription:
                            scopeDescription,
                        hasActiveSearch:
                            hasActiveSearch,
                        warningSentence:
                            warningSentence
                    ),
                actionButtonTitle:
                    "Clear \(normalItemCount) " +
                    scopeDescription
            )

        case .includingPinned:
            return ClipboardClearConfirmationDescriptor(
                menuTitle:
                    includingPinnedMenuTitle(
                        contentScope: contentScope,
                        hasActiveSearch:
                            hasActiveSearch
                    ),
                alertTitle:
                    includingPinnedAlertTitle(
                        contentScope: contentScope,
                        count: normalItemCount,
                        hasActiveSearch:
                            hasActiveSearch
                    ),
                informativeText:
                    includingPinnedInformativeText(
                        scopeDescription:
                            scopeDescription,
                        hasActiveSearch:
                            hasActiveSearch,
                        warningSentence:
                            warningSentence
                    ),
                actionButtonTitle:
                    "Clear \(normalItemCount) " +
                    scopeDescription
            )
        }
    }

    private static func warningOnlyDescriptor(
        warningCount: Int,
        hasActiveSearch: Bool
    ) -> ClipboardClearConfirmationDescriptor {
        let warningWord =
            warningCount == 1
                ? "Warning"
                : "Warnings"

        let matchingText =
            hasActiveSearch
                ? "Matching "
                : ""

        return ClipboardClearConfirmationDescriptor(
            menuTitle:
                "Clear \(matchingText)\(warningWord)…",
            alertTitle:
                "Clear \(warningCount) " +
                "\(matchingText)\(warningWord)?",
            informativeText:
                """
                This will remove the temporary warning \
                rows in the current view.
                """,
            actionButtonTitle:
                "Clear \(warningCount) \(warningWord)"
        )
    }

    private static func unpinnedMenuTitle(
        contentScope: ClipboardClearContentScope,
        hasActiveSearch: Bool
    ) -> String {
        if hasActiveSearch {
            switch contentScope {
            case .all:
                return
                    "Clear Matching Unpinned Items…"

            case .text:
                return
                    "Clear Matching Unpinned Text…"

            case .links:
                return
                    "Clear Matching Unpinned Links…"

            case .images:
                return
                    "Clear Matching Unpinned Images…"

            case .files:
                return
                    "Clear Matching Unpinned Files…"
            }
        }

        switch contentScope {
        case .all:
            return
                "Clear All Unpinned History…"

        case .text:
            return
                "Clear Unpinned Text…"

        case .links:
            return
                "Clear Unpinned Links…"

        case .images:
            return
                "Clear Unpinned Images…"

        case .files:
            return
                "Clear Unpinned Files…"
        }
    }

    private static func includingPinnedMenuTitle(
        contentScope: ClipboardClearContentScope,
        hasActiveSearch: Bool
    ) -> String {
        if hasActiveSearch {
            switch contentScope {
            case .all:
                return
                    """
                    Clear All Matching Items, \
                    Including Pinned…
                    """

            case .text:
                return
                    """
                    Clear All Matching Text, \
                    Including Pinned…
                    """

            case .links:
                return
                    """
                    Clear All Matching Links, \
                    Including Pinned…
                    """

            case .images:
                return
                    """
                    Clear All Matching Images, \
                    Including Pinned…
                    """

            case .files:
                return
                    """
                    Clear All Matching Files, \
                    Including Pinned…
                    """
            }
        }

        switch contentScope {
        case .all:
            return
                """
                Clear All History, \
                Including Pinned…
                """

        case .text:
            return
                """
                Clear All Text, \
                Including Pinned…
                """

        case .links:
            return
                """
                Clear All Links, \
                Including Pinned…
                """

        case .images:
            return
                """
                Clear All Images, \
                Including Pinned…
                """

        case .files:
            return
                """
                Clear All Files, \
                Including Pinned…
                """
        }
    }

    private static func unpinnedAlertTitle(
        contentScope: ClipboardClearContentScope,
        count: Int,
        hasActiveSearch: Bool
    ) -> String {
        let matchingText =
            hasActiveSearch
                ? " Matching"
                : ""

        return
            "Clear \(count)\(matchingText) " +
            description(
                for: contentScope,
                count: count
            ) +
            "?"
    }

    private static func includingPinnedAlertTitle(
        contentScope: ClipboardClearContentScope,
        count: Int,
        hasActiveSearch: Bool
    ) -> String {
        let matchingText =
            hasActiveSearch
                ? " Matching"
                : ""

        return
            "Clear \(count)\(matchingText) " +
            description(
                for: contentScope,
                count: count
            ) +
            ", Including Pinned?"
    }

    private static func unpinnedInformativeText(
        scopeDescription: String,
        hasActiveSearch: Bool,
        warningSentence: String
    ) -> String {
        let searchSentence =
            hasActiveSearch
                ? " matching the current search"
                : ""

        return
            """
            This will permanently remove the unpinned \
            \(scopeDescription)\(searchSentence). \
            Pinned items will remain.\(warningSentence)
            """
    }

    private static func includingPinnedInformativeText(
        scopeDescription: String,
        hasActiveSearch: Bool,
        warningSentence: String
    ) -> String {
        let searchSentence =
            hasActiveSearch
                ? " matching the current search"
                : ""

        return
            """
            This will permanently remove the \
            \(scopeDescription)\(searchSentence), \
            including any pinned items in the current \
            results.\(warningSentence)
            """
    }

    private static func additionalWarningSentence(
        warningCount: Int
    ) -> String {
        guard warningCount > 0 else {
            return ""
        }

        let warningWord =
            warningCount == 1
                ? "warning row"
                : "warning rows"

        return
            " \(warningCount) matching " +
            "\(warningWord) will also be removed."
    }

    private static func description(
        for contentScope: ClipboardClearContentScope,
        count: Int
    ) -> String {
        switch contentScope {
        case .all:
            return count == 1
                ? "Item"
                : "Items"

        case .text:
            return count == 1
                ? "Text Item"
                : "Text Items"

        case .links:
            return count == 1
                ? "Link"
                : "Links"

        case .images:
            return count == 1
                ? "Image"
                : "Images"

        case .files:
            return count == 1
                ? "File"
                : "Files"
        }
    }
}
