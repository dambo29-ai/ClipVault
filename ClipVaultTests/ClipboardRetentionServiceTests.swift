//
//  ClipboardRetentionServiceTests.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/13/26.
//

import XCTest
@testable import ClipVault

@MainActor
final class ClipboardRetentionServiceTests: XCTestCase {
    func testExpiredCapturedClipIsRemoved() {
        let now = date(2026, 7, 13)

        let expiredItem = makeItem(
            text: "Expired captured clip",
            createdAt: now.addingTimeInterval(
                -(2 * 24 * 60 * 60)
            ),
            origin: .captured
        )

        let result =
            ClipboardRetentionService.removingExpiredItems(
                from: [expiredItem],
                retentionOption: .oneDay,
                now: now
            )

        XCTAssertTrue(result.isEmpty)
    }

    func testRecentCapturedClipIsRetained() {
        let now = date(2026, 7, 13)

        let recentItem = makeItem(
            text: "Recent captured clip",
            createdAt: now.addingTimeInterval(
                -(12 * 60 * 60)
            ),
            origin: .captured
        )

        let result =
            ClipboardRetentionService.removingExpiredItems(
                from: [recentItem],
                retentionOption: .oneDay,
                now: now
            )

        XCTAssertEqual(result, [recentItem])
    }

    func testOldRestoredClipIsRetained() {
        let now = date(2026, 7, 13)

        let restoredItem = makeItem(
            text: "Historical restored clip",
            createdAt: date(2020, 1, 1),
            origin: .restored
        )

        let result =
            ClipboardRetentionService.removingExpiredItems(
                from: [restoredItem],
                retentionOption: .oneDay,
                now: now
            )

        XCTAssertEqual(result, [restoredItem])
    }

    func testForeverRetentionKeepsCapturedClipsRegardlessOfAge() {
        let oldCapturedItem = makeItem(
            text: "Old captured clip",
            createdAt: date(2020, 1, 1),
            origin: .captured
        )

        let result =
            ClipboardRetentionService.removingExpiredItems(
                from: [oldCapturedItem],
                retentionOption: .forever,
                now: date(2026, 7, 13)
            )

        XCTAssertEqual(result, [oldCapturedItem])
    }

    func testWarningRowsAreNotRemovedByAgeRetention() {
        let warningItem = makeItem(
            text: "Warning",
            createdAt: date(2020, 1, 1),
            kind: .sensitiveSkipped
        )

        let result =
            ClipboardRetentionService.removingExpiredItems(
                from: [warningItem],
                retentionOption: .oneDay,
                now: date(2026, 7, 13)
            )

        XCTAssertEqual(result, [warningItem])
    }

    func testWarningRowsDoNotConsumeNormalHistoryLimit() {
        let normalItems = (1...10).map {
            makeItem(text: "Normal \($0)")
        }

        let warningItem = makeItem(
            text: "Warning",
            kind: .sensitiveSkipped
        )

        let result =
            ClipboardRetentionService.trimmingNormalItems(
                in: [warningItem] + normalItems,
                maximumNormalItemCount: 10
            )

        XCTAssertEqual(
            result.filter { $0.kind == .normal }.count,
            10
        )

        XCTAssertTrue(
            result.contains {
                $0.id == warningItem.id
            }
        )
    }

    func testOnlyOldestExcessNormalItemsAreRemoved() {
        let items = [
            makeItem(text: "Newest"),
            makeItem(text: "Middle"),
            makeItem(text: "Oldest")
        ]

        let result =
            ClipboardRetentionService.trimmingNormalItems(
                in: items,
                maximumNormalItemCount: 2
            )

        XCTAssertEqual(
            result.map(\.text),
            ["Newest", "Middle"]
        )
    }

    func testCombinedRulesRemoveExpiredCapturedClipAndPreserveRestoredClip() {
        let now = date(2026, 7, 13)

        let expiredCapturedItem = makeItem(
            text: "Expired captured",
            createdAt: date(2020, 1, 1),
            origin: .captured
        )

        let restoredItem = makeItem(
            text: "Restored",
            createdAt: date(2020, 1, 1),
            origin: .restored
        )

        let recentCapturedItem = makeItem(
            text: "Recent captured",
            createdAt: now,
            origin: .captured
        )

        let result =
            ClipboardRetentionService.applyingRules(
                to: [
                    recentCapturedItem,
                    restoredItem,
                    expiredCapturedItem
                ],
                retentionOption: .oneDay,
                maximumNormalItemCount: 10,
                now: now
            )

        XCTAssertEqual(
            result.map(\.text),
            ["Recent captured", "Restored"]
        )
    }

    private func makeItem(
        text: String,
        createdAt: Date = Date(),
        kind: ClipboardItemKind = .normal,
        origin: ClipboardItemOrigin = .captured
    ) -> ClipboardItem {
        ClipboardItem(
            text: text,
            createdAt: createdAt,
            kind: kind,
            origin: origin
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

