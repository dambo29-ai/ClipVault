//
//  ClipboardClearScopeServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/15/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardClearScopeServiceTests {
    @Test
    func allScopeIncludesEveryItemWithoutSearch() {
        let textItem =
            makeItem(
                text: "Ordinary text"
            )

        let linkItem =
            makeItem(
                text: "https://example.com"
            )

        let warningItem =
            makeWarning(
                text: "Skipped warning"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [
                    textItem,
                    linkItem,
                    warningItem
                ],
                contentScope: .all,
                searchText: ""
            )

        #expect(
            result.normalItems ==
                [
                    textItem,
                    linkItem
                ]
        )

        #expect(
            result.warningItems ==
                [
                    warningItem
                ]
        )

        #expect(result.normalItemCount == 2)
        #expect(result.warningCount == 1)
    }

    @Test
    func textScopeExcludesLinksAndIncludesWarnings() {
        let textItem =
            makeItem(
                text: "Ordinary text"
            )

        let linkItem =
            makeItem(
                text: "https://example.com"
            )

        let warningItem =
            makeWarning(
                text: "Skipped warning"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [
                    textItem,
                    linkItem,
                    warningItem
                ],
                contentScope: .text,
                searchText: ""
            )

        #expect(
            result.normalItems ==
                [
                    textItem
                ]
        )

        #expect(
            result.warningItems ==
                [
                    warningItem
                ]
        )
    }

    @Test
    func linksScopeIncludesOnlyLinks() {
        let textItem =
            makeItem(
                text: "Ordinary text"
            )

        let linkItem =
            makeItem(
                text: "https://example.com"
            )

        let warningItem =
            makeWarning(
                text: "Skipped warning"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [
                    textItem,
                    linkItem,
                    warningItem
                ],
                contentScope: .links,
                searchText: ""
            )

        #expect(
            result.normalItems ==
                [
                    linkItem
                ]
        )

        #expect(result.warningItems.isEmpty)
    }

    @Test
    func searchRestrictsAllScopeToMatchingItems() {
        let firstMatch =
            makeItem(
                text: "Apple invoice"
            )

        let secondMatch =
            makeItem(
                text: "https://apple.com"
            )

        let nonMatch =
            makeItem(
                text: "Orange receipt"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [
                    firstMatch,
                    secondMatch,
                    nonMatch
                ],
                contentScope: .all,
                searchText: "apple"
            )

        #expect(
            result.normalItems ==
                [
                    firstMatch,
                    secondMatch
                ]
        )
    }

    @Test
    func searchIsCaseInsensitive() {
        let matchingItem =
            makeItem(
                text: "Vendor Invoice"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [matchingItem],
                contentScope: .text,
                searchText: "invoice"
            )

        #expect(
            result.normalItems ==
                [
                    matchingItem
                ]
        )
    }

    @Test
    func searchTrimsSurroundingWhitespace() {
        let matchingItem =
            makeItem(
                text: "Travel itinerary"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [matchingItem],
                contentScope: .text,
                searchText: "  itinerary \n"
            )

        #expect(
            result.normalItems ==
                [
                    matchingItem
                ]
        )
    }

    @Test
    func unpinnedScopeIdentifiersExcludePinsButIncludeWarnings() {
        let unpinnedItem =
            makeItem(
                text: "Unpinned"
            )

        let pinnedItem =
            makeItem(
                text: "Pinned",
                isPinned: true
            )

        let warningItem =
            makeWarning(
                text: "Warning"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [
                    unpinnedItem,
                    pinnedItem,
                    warningItem
                ],
                contentScope: .all,
                searchText: ""
            )

        #expect(
            result.unpinnedNormalItems ==
                [
                    unpinnedItem
                ]
        )

        #expect(
            result.pinnedNormalItems ==
                [
                    pinnedItem
                ]
        )

        #expect(
            result.unpinnedItemIDsIncludingWarnings ==
                Set([
                    unpinnedItem.id,
                    warningItem.id
                ])
        )
    }

    @Test
    func allIdentifiersIncludePinnedUnpinnedAndWarnings() {
        let unpinnedItem =
            makeItem(
                text: "Unpinned"
            )

        let pinnedItem =
            makeItem(
                text: "Pinned",
                isPinned: true
            )

        let warningItem =
            makeWarning(
                text: "Warning"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [
                    unpinnedItem,
                    pinnedItem,
                    warningItem
                ],
                contentScope: .all,
                searchText: ""
            )

        #expect(
            result.allItemIDs ==
                Set([
                    unpinnedItem.id,
                    pinnedItem.id,
                    warningItem.id
                ])
        )
    }

    @Test
    func warningOnlyResultReportsNoNormalItems() {
        let warningItem =
            makeWarning(
                text: "Matching warning"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [warningItem],
                contentScope: .text,
                searchText: "matching"
            )

        #expect(result.normalItemCount == 0)
        #expect(result.unpinnedNormalItemCount == 0)
        #expect(result.pinnedNormalItemCount == 0)
        #expect(result.warningCount == 1)
        #expect(!result.isEmpty)
    }

    @Test
    func emptyResultReportsEmpty() {
        let item =
            makeItem(
                text: "Ordinary text"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [item],
                contentScope: .links,
                searchText: ""
            )

        #expect(result.isEmpty)
        #expect(result.allItemIDs.isEmpty)
    }

    @Test
    func imagesScopeIsEmptyUntilImageSupportExists() {
        let item =
            makeItem(
                text: "Ordinary text"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [item],
                contentScope: .images,
                searchText: ""
            )

        #expect(result.isEmpty)
    }

    @Test
    func filesScopeIsEmptyUntilFileSupportExists() {
        let item =
            makeItem(
                text: "Ordinary text"
            )

        let result =
            ClipboardClearScopeService.result(
                from: [item],
                contentScope: .files,
                searchText: ""
            )

        #expect(result.isEmpty)
    }

    private func makeItem(
        text: String,
        isPinned: Bool = false
    ) -> ClipboardItem {
        ClipboardItem(
            text: text,
            isPinned: isPinned,
            pinnedAt:
                isPinned
                    ? Date()
                    : nil
        )
    }

    private func makeWarning(
        text: String
    ) -> ClipboardItem {
        ClipboardItem(
            text: text,
            kind: .sensitiveSkipped
        )
    }
}
