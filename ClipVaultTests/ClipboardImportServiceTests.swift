//
//  ClipVaultTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/12/26.
//

import XCTest
@testable import ClipVault

@MainActor
final class ClipboardImportServiceTests: XCTestCase {
    func testCompleteMergeReturnsAllPreparedItemsBeforeLimitChoice() {
        let existingItems = [
            makeItem(
                text: "Existing",
                createdAt: date(2026, 7, 10)
            )
        ]

        let backupItems = (1...12).map {
            makeItem(
                text: "Backup \($0)",
                createdAt: date(2026, 6, $0)
            )
        }

        let result =
            ClipboardImportService
                .prepareCompleteMerge(
                    existingItems: existingItems,
                    backupItems: backupItems
                )

        XCTAssertEqual(
            result.preparedItems.count,
            13
        )

        XCTAssertEqual(
            result.importedCount,
            12
        )

        XCTAssertEqual(
            result.duplicateCount,
            0
        )

        XCTAssertEqual(
            result.requiredUnpinnedItemCount,
            13
        )
    }

    func testCompleteReplacementReturnsAllItemsBeforeLimitChoice() {
        let backupItems = (1...12).map {
            makeItem(
                text: "Backup \($0)",
                createdAt: date(2026, 7, $0)
            )
        }

        let result =
            ClipboardImportService
                .prepareCompleteReplacement(
                    backupItems: backupItems
                )

        XCTAssertEqual(
            result.preparedItems.count,
            12
        )

        XCTAssertEqual(
            result.requiredUnpinnedItemCount,
            12
        )
    }

    func testCompleteMergeExcludesPinnedItemsFromRequiredCapacity() {
        let existingPinnedItem =
            makeItem(
                text: "Existing pin",
                isPinned: true,
                pinnedAt: date(2026, 7, 15)
            )

        let backupPinnedItem =
            makeItem(
                text: "Backup pin",
                isPinned: true,
                pinnedAt: date(2026, 7, 14)
            )

        let backupUnpinnedItem =
            makeItem(
                text: "Backup unpinned"
            )

        let result =
            ClipboardImportService
                .prepareCompleteMerge(
                    existingItems: [
                        existingPinnedItem
                    ],
                    backupItems: [
                        backupPinnedItem,
                        backupUnpinnedItem
                    ]
                )

        XCTAssertEqual(
            result.preparedItems.count,
            3
        )

        XCTAssertEqual(
            result.requiredUnpinnedItemCount,
            1
        )

        XCTAssertEqual(
            result.preparedItems.filter {
                $0.isPinned
            }
            .count,
            2
        )
    }

    func testCompleteReplacementPreservesPinsBeyondHistoryCapacity() {
        let pinnedItems = (1...3).map {
            makeItem(
                text: "Pinned \($0)",
                createdAt: date(2020, 1, $0),
                isPinned: true,
                pinnedAt: date(2026, 7, $0)
            )
        }

        let unpinnedItems = (1...10).map {
            makeItem(
                text: "Unpinned \($0)",
                createdAt: date(2026, 6, $0)
            )
        }

        let result =
            ClipboardImportService
                .prepareCompleteReplacement(
                    backupItems:
                        pinnedItems +
                        unpinnedItems
                )

        XCTAssertEqual(
            result.preparedItems.count,
            13
        )

        XCTAssertEqual(
            result.requiredUnpinnedItemCount,
            10
        )

        XCTAssertEqual(
            result.preparedItems.filter {
                $0.isPinned
            }
            .count,
            3
        )
    }

    func testPinnedBackupDuplicateReplacesExistingUnpinnedItem() {
        let existingItem =
            makeItem(
                text: "Reusable item",
                createdAt: date(2026, 7, 10)
            )

        let backupPinnedItem =
            makeItem(
                text: "Reusable item",
                createdAt: date(2026, 7, 1),
                isPinned: true,
                pinnedAt: date(2026, 7, 15)
            )

        let result =
            ClipboardImportService
                .prepareCompleteMerge(
                    existingItems: [
                        existingItem
                    ],
                    backupItems: [
                        backupPinnedItem
                    ]
                )

        XCTAssertEqual(
            result.preparedItems.count,
            1
        )

        XCTAssertTrue(
            result.preparedItems[0].isPinned
        )

        XCTAssertEqual(
            result.preparedItems[0].origin,
            .restored
        )

        XCTAssertEqual(
            result.importedCount,
            1
        )

        XCTAssertEqual(
            result.duplicateCount,
            0
        )
    }

    func testExistingPinnedItemWinsOverBackupUnpinnedDuplicate() {
        let existingPinnedItem =
            makeItem(
                text: "Reusable item",
                isPinned: true,
                pinnedAt: date(2026, 7, 15)
            )

        let backupUnpinnedItem =
            makeItem(
                text: "Reusable item"
            )

        let result =
            ClipboardImportService
                .prepareCompleteMerge(
                    existingItems: [
                        existingPinnedItem
                    ],
                    backupItems: [
                        backupUnpinnedItem
                    ]
                )

        XCTAssertEqual(
            result.preparedItems,
            [existingPinnedItem]
        )

        XCTAssertEqual(
            result.importedCount,
            0
        )

        XCTAssertEqual(
            result.duplicateCount,
            1
        )
    }

    func testPinnedDuplicateWithinReplacementWins() {
        let unpinnedItem =
            makeItem(
                text: "Reusable item",
                createdAt: date(2026, 7, 15)
            )

        let pinnedItem =
            makeItem(
                text: "Reusable item",
                createdAt: date(2026, 7, 1),
                isPinned: true,
                pinnedAt: date(2026, 7, 15)
            )

        let result =
            ClipboardImportService
                .prepareCompleteReplacement(
                    backupItems: [
                        unpinnedItem,
                        pinnedItem
                    ]
                )

        XCTAssertEqual(
            result.preparedItems.count,
            1
        )

        XCTAssertTrue(
            result.preparedItems[0].isPinned
        )

        XCTAssertEqual(
            result.requiredUnpinnedItemCount,
            0
        )
    }
    
    func testKeepLimitPreservesPinsAndNewestUnpinnedItems() {
        let pinnedItems = [
            makeItem(
                text: "Pinned newest",
                createdAt: date(2026, 7, 15),
                isPinned: true,
                pinnedAt: date(2026, 7, 15)
            ),
            makeItem(
                text: "Pinned oldest",
                createdAt: date(2020, 1, 1),
                isPinned: true,
                pinnedAt: date(2026, 7, 1)
            )
        ]

        let unpinnedItems = [
            makeItem(
                text: "Unpinned newest",
                createdAt: date(2026, 7, 14)
            ),
            makeItem(
                text: "Unpinned middle",
                createdAt: date(2026, 7, 13)
            ),
            makeItem(
                text: "Unpinned oldest",
                createdAt: date(2026, 7, 12)
            )
        ]

        let preparedItems =
            (
                pinnedItems +
                unpinnedItems
            )
            .sorted {
                $0.createdAt > $1.createdAt
            }

        let result =
            ClipboardImportService.resolveHistoryLimit(
                for: preparedItems,
                currentHistoryLimit: 2,
                maximumHistoryLimit: 500,
                decision: .keepLimit
            )

        XCTAssertEqual(
            result.resultingHistoryLimit,
            2
        )

        XCTAssertFalse(
            result.didExpandHistoryLimit
        )

        XCTAssertEqual(
            result.skippedUnpinnedItemCount,
            1
        )

        XCTAssertEqual(
            result.resolvedItems.filter {
                $0.isPinned
            }
            .count,
            2
        )

        XCTAssertEqual(
            result.resolvedItems.filter {
                !$0.isPinned
            }
            .map(\.text),
            [
                "Unpinned newest",
                "Unpinned middle"
            ]
        )
    }

    func testExpandLimitRoundsUpAndPreservesAllItems() {
        let preparedItems =
            (1...23).map {
                makeItem(
                    text: "Item \($0)",
                    createdAt:
                        date(
                            2026,
                            6,
                            min($0, 28)
                        )
                )
            }

        let result =
            ClipboardImportService.resolveHistoryLimit(
                for: preparedItems,
                currentHistoryLimit: 10,
                maximumHistoryLimit: 500,
                decision: .expandLimit
            )

        XCTAssertEqual(
            result.resultingHistoryLimit,
            30
        )

        XCTAssertTrue(
            result.didExpandHistoryLimit
        )

        XCTAssertEqual(
            result.skippedUnpinnedItemCount,
            0
        )

        XCTAssertEqual(
            result.resolvedItems.count,
            23
        )
    }

    func testExpandLimitDoesNotDecreaseCurrentLimit() {
        let preparedItems =
            (1...12).map {
                makeItem(
                    text: "Item \($0)"
                )
            }

        let result =
            ClipboardImportService.resolveHistoryLimit(
                for: preparedItems,
                currentHistoryLimit: 30,
                maximumHistoryLimit: 500,
                decision: .expandLimit
            )

        XCTAssertEqual(
            result.resultingHistoryLimit,
            30
        )

        XCTAssertFalse(
            result.didExpandHistoryLimit
        )

        XCTAssertEqual(
            result.skippedUnpinnedItemCount,
            0
        )
    }

    func testExpandLimitRespectsMaximumAndReportsSkippedItems() {
        let pinnedItem =
            makeItem(
                text: "Pinned",
                isPinned: true,
                pinnedAt: date(2026, 7, 15)
            )

        let unpinnedItems =
            (1...12).map {
                makeItem(
                    text: "Unpinned \($0)"
                )
            }

        let result =
            ClipboardImportService.resolveHistoryLimit(
                for:
                    [pinnedItem] +
                    unpinnedItems,
                currentHistoryLimit: 5,
                maximumHistoryLimit: 10,
                decision: .expandLimit
            )

        XCTAssertEqual(
            result.resultingHistoryLimit,
            10
        )

        XCTAssertTrue(
            result.didExpandHistoryLimit
        )

        XCTAssertEqual(
            result.skippedUnpinnedItemCount,
            2
        )

        XCTAssertTrue(
            result.resolvedItems.contains {
                $0.id == pinnedItem.id
            }
        )

        XCTAssertEqual(
            result.resolvedItems.filter {
                !$0.isPinned
            }
            .count,
            10
        )
    }

    func testKeepLimitWithZeroCapacityStillPreservesPins() {
        let pinnedItem =
            makeItem(
                text: "Pinned",
                isPinned: true,
                pinnedAt: date(2026, 7, 15)
            )

        let unpinnedItem =
            makeItem(
                text: "Unpinned"
            )

        let result =
            ClipboardImportService.resolveHistoryLimit(
                for: [
                    pinnedItem,
                    unpinnedItem
                ],
                currentHistoryLimit: 0,
                maximumHistoryLimit: 500,
                decision: .keepLimit
            )

        XCTAssertEqual(
            result.resolvedItems,
            [pinnedItem]
        )

        XCTAssertEqual(
            result.skippedUnpinnedItemCount,
            1
        )

        XCTAssertEqual(
            result.resultingHistoryLimit,
            0
        )
    }
    
    func testRequiredCapacityCountsOnlyUnpinnedNormalItems() {
        let unpinnedItems = [
            makeItem(text: "Unpinned 1"),
            makeItem(text: "Unpinned 2")
        ]

        let pinnedItems = [
            makeItem(
                text: "Pinned 1",
                isPinned: true,
                pinnedAt: date(2026, 7, 1)
            ),
            makeItem(
                text: "Pinned 2",
                isPinned: true,
                pinnedAt: date(2026, 7, 2)
            )
        ]

        let warningItem =
            makeItem(
                text: "Warning",
                kind: .sensitiveSkipped
            )

        let result =
            ClipboardImportService
                .requiredUnpinnedItemCount(
                    in:
                        unpinnedItems +
                        pinnedItems +
                        [warningItem]
                )

        XCTAssertEqual(result, 2)
    }

    func testRoundedHistoryLimitRoundsUpToNearestTen() {
        XCTAssertEqual(
            ClipboardImportService.roundedHistoryLimit(
                requiredItemCount: 11
            ),
            20
        )

        XCTAssertEqual(
            ClipboardImportService.roundedHistoryLimit(
                requiredItemCount: 23
            ),
            30
        )

        XCTAssertEqual(
            ClipboardImportService.roundedHistoryLimit(
                requiredItemCount: 40
            ),
            40
        )

        XCTAssertEqual(
            ClipboardImportService.roundedHistoryLimit(
                requiredItemCount: 41
            ),
            50
        )
    }

    func testApplyingHistoryLimitPreservesAllPinnedItems() {
        let pinnedNewest =
            makeItem(
                text: "Pinned newest",
                createdAt: date(2026, 7, 15),
                isPinned: true,
                pinnedAt: date(2026, 7, 15)
            )

        let unpinnedNewest =
            makeItem(
                text: "Unpinned newest",
                createdAt: date(2026, 7, 14)
            )

        let pinnedOldest =
            makeItem(
                text: "Pinned oldest",
                createdAt: date(2020, 1, 1),
                isPinned: true,
                pinnedAt: date(2026, 7, 1)
            )

        let unpinnedMiddle =
            makeItem(
                text: "Unpinned middle",
                createdAt: date(2026, 7, 13)
            )

        let unpinnedOldest =
            makeItem(
                text: "Unpinned oldest",
                createdAt: date(2026, 7, 12)
            )

        let result =
            ClipboardImportService.applyingHistoryLimit(
                to: [
                    pinnedNewest,
                    unpinnedNewest,
                    pinnedOldest,
                    unpinnedMiddle,
                    unpinnedOldest
                ],
                maximumUnpinnedItemCount: 2
            )

        XCTAssertEqual(
            result.map(\.text),
            [
                "Pinned newest",
                "Unpinned newest",
                "Pinned oldest",
                "Unpinned middle"
            ]
        )

        XCTAssertTrue(
            result.contains {
                $0.id == pinnedNewest.id
            }
        )

        XCTAssertTrue(
            result.contains {
                $0.id == pinnedOldest.id
            }
        )

        XCTAssertFalse(
            result.contains {
                $0.id == unpinnedOldest.id
            }
        )
    }

    func testApplyingHistoryLimitKeepsNewestUnpinnedItems() {
        let newest =
            makeItem(
                text: "Newest",
                createdAt: date(2026, 7, 15)
            )

        let middle =
            makeItem(
                text: "Middle",
                createdAt: date(2026, 7, 14)
            )

        let oldest =
            makeItem(
                text: "Oldest",
                createdAt: date(2026, 7, 13)
            )

        let result =
            ClipboardImportService.applyingHistoryLimit(
                to: [
                    newest,
                    middle,
                    oldest
                ],
                maximumUnpinnedItemCount: 2
            )

        XCTAssertEqual(
            result.map(\.text),
            [
                "Newest",
                "Middle"
            ]
        )
    }

    func testApplyingZeroHistoryLimitStillPreservesPins() {
        let pinnedItem =
            makeItem(
                text: "Pinned",
                isPinned: true,
                pinnedAt: date(2026, 7, 15)
            )

        let unpinnedItem =
            makeItem(
                text: "Unpinned"
            )

        let result =
            ClipboardImportService.applyingHistoryLimit(
                to: [
                    pinnedItem,
                    unpinnedItem
                ],
                maximumUnpinnedItemCount: 0
            )

        XCTAssertEqual(
            result,
            [pinnedItem]
        )
    }
    
    func testOlderClipboardItemWithoutOriginDecodesAsCaptured() throws {
        let itemID = UUID()

        let json = """
        {
          "id": "\(itemID.uuidString)",
          "text": "Legacy clip",
          "createdAt": "2020-01-01T12:00:00Z",
          "kind": "normal",
          "sourceAppName": "TextEdit",
          "sourceBundleIdentifier": "com.apple.TextEdit"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let item = try decoder.decode(
            ClipboardItem.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(item.id, itemID)
        XCTAssertEqual(item.text, "Legacy clip")
        XCTAssertEqual(item.kind, .normal)
        XCTAssertEqual(item.origin, .captured)
        XCTAssertEqual(item.sourceAppName, "TextEdit")
        XCTAssertEqual(
            item.sourceBundleIdentifier,
            "com.apple.TextEdit"
        )
    }

    func testCurrentClipboardItemPreservesRestoredOrigin() throws {
        let originalItem = makeItem(
            text: "Restored clip",
            createdAt: date(2020, 1, 1),
            origin: .restored
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(originalItem)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decodedItem = try decoder.decode(
            ClipboardItem.self,
            from: data
        )

        XCTAssertEqual(decodedItem.id, originalItem.id)
        XCTAssertEqual(decodedItem.text, originalItem.text)
        XCTAssertEqual(
            decodedItem.createdAt,
            originalItem.createdAt
        )
        XCTAssertEqual(decodedItem.origin, .restored)
    }

    private func makeItem(
        text: String,
        createdAt: Date = Date(),
        kind: ClipboardItemKind = .normal,
        origin: ClipboardItemOrigin = .captured,
        isPinned: Bool = false,
        pinnedAt: Date? = nil
    ) -> ClipboardItem {
        ClipboardItem(
            text: text,
            createdAt: createdAt,
            kind: kind,
            origin: origin,
            isPinned: isPinned,
            pinnedAt: pinnedAt
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(
            identifier: .gregorian
        )
        components.timeZone = TimeZone(
            secondsFromGMT: 0
        )
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12

        return components.date!
    }
}


