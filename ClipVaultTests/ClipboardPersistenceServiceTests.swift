//
//  ClipboardPersistenceServiceTests.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/13/26.
//

import XCTest
@testable import ClipVault

@MainActor
final class ClipboardPersistenceServiceTests: XCTestCase {
    func testSavingAndLoadingNormalItemsPreservesContent() async throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        let service = ClipboardPersistenceService(
            storageURL: testStorage.fileURL
        )

        let originalItems = [
            makeItem(
                text: "First persisted clip",
                createdAt: date(2026, 7, 12),
                origin: .captured
            ),
            makeItem(
                text: "Historical restored clip",
                createdAt: date(2020, 1, 1),
                origin: .restored
            )
        ]

        try await service.saveItems(originalItems)

        let loadedItems = try await service.loadItems()

        XCTAssertEqual(loadedItems, originalItems)
    }

    func testSavingCreatesMissingParentDirectory() async throws {
        let testStorage = try makeTestStorage(
            createDirectory: false
        )

        defer {
            removeTestStorage(testStorage)
        }

        let service = ClipboardPersistenceService(
            storageURL: testStorage.fileURL
        )

        try await service.saveItems([
            makeItem(text: "Directory creation test")
        ])

        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: testStorage.fileURL.path
            )
        )
    }

    func testLoadingMissingFileReturnsEmptyHistory() async throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        let service = ClipboardPersistenceService(
            storageURL: testStorage.fileURL
        )

        let loadedItems = try await service.loadItems()

        XCTAssertTrue(loadedItems.isEmpty)
    }

    func testWarningRowsAreExcludedFromSavedHistory() async throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        let service = ClipboardPersistenceService(
            storageURL: testStorage.fileURL
        )

        let normalItem = makeItem(
            text: "Normal clip"
        )

        let warningItem = makeItem(
            text: "Sensitive clip warning",
            kind: .sensitiveSkipped
        )

        try await service.saveItems([
            normalItem,
            warningItem
        ])

        let loadedItems = try await service.loadItems()

        XCTAssertEqual(loadedItems, [normalItem])

        XCTAssertFalse(
            loadedItems.contains {
                $0.kind == .sensitiveSkipped
            }
        )
    }

    func testRestoredOriginSurvivesPersistence() async throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        let service = ClipboardPersistenceService(
            storageURL: testStorage.fileURL
        )

        let restoredItem = makeItem(
            text: "Restored history",
            createdAt: date(2019, 6, 15),
            origin: .restored
        )

        try await service.saveItems([
            restoredItem
        ])

        let loadedItems = try await service.loadItems()

        XCTAssertEqual(loadedItems.count, 1)
        XCTAssertEqual(
            loadedItems.first?.origin,
            .restored
        )

        XCTAssertEqual(
            loadedItems.first?.createdAt,
            restoredItem.createdAt
        )
    }
    
    func testPinnedStateSurvivesPersistence() async throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        let service = ClipboardPersistenceService(
            storageURL: testStorage.fileURL
        )

        let pinDate = date(2026, 7, 15)

        let pinnedItem = makeItem(
            text: "Pinned clipboard item",
            createdAt: date(2026, 7, 14),
            isPinned: true,
            pinnedAt: pinDate
        )

        try await service.saveItems([
            pinnedItem
        ])

        let loadedItems = try await service.loadItems()

        XCTAssertEqual(loadedItems.count, 1)
        XCTAssertEqual(
            loadedItems.first?.isPinned,
            true
        )
        XCTAssertEqual(
            loadedItems.first?.pinnedAt,
            pinDate
        )
        XCTAssertEqual(
            loadedItems.first,
            pinnedItem
        )
    }

    func testLegacySavedItemWithoutOriginDecodesAsCaptured() throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        let itemID = UUID()

        let legacyJSON = """
        [
          {
            "id": "\(itemID.uuidString)",
            "text": "Legacy persisted clip",
            "createdAt": 599572800,
            "kind": "normal",
            "sourceAppName": null,
            "sourceBundleIdentifier": null
          }
        ]
        """

        try Data(legacyJSON.utf8).write(
            to: testStorage.fileURL,
            options: .atomic
        )

        let loadedItems =
            try ClipboardPersistenceService.loadItems(
                from: testStorage.fileURL
            )

        XCTAssertEqual(loadedItems.count, 1)
        XCTAssertEqual(
            loadedItems.first?.id,
            itemID
        )

        XCTAssertEqual(
            loadedItems.first?.text,
            "Legacy persisted clip"
        )

        XCTAssertEqual(
            loadedItems.first?.origin,
            .captured
        )

        XCTAssertEqual(
            loadedItems.first?.isPinned,
            false
        )

        XCTAssertNil(
            loadedItems.first?.pinnedAt
        )
    }
    
    func testUnpinnedItemDiscardsStoredPinnedDate() throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        let itemID = UUID()

        let storedJSON = """
        [
          {
            "id": "\(itemID.uuidString)",
            "text": "Unpinned item with stale pin date",
            "createdAt": 599572800,
            "kind": "normal",
            "sourceAppName": null,
            "sourceBundleIdentifier": null,
            "origin": "captured",
            "isPinned": false,
            "pinnedAt": 600000000
          }
        ]
        """

        try Data(storedJSON.utf8).write(
            to: testStorage.fileURL,
            options: .atomic
        )

        let loadedItems =
            try ClipboardPersistenceService.loadItems(
                from: testStorage.fileURL
            )

        XCTAssertEqual(loadedItems.count, 1)
        XCTAssertEqual(
            loadedItems.first?.isPinned,
            false
        )
        XCTAssertNil(
            loadedItems.first?.pinnedAt
        )
    }

    func testStaticLoadFiltersWarningRowsFromExistingFile() throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        let normalItem = makeItem(
            text: "Normal stored item"
        )

        let warningItem = makeItem(
            text: "Stored warning",
            kind: .sensitiveSkipped
        )

        let encoder = JSONEncoder()

        let data = try encoder.encode([
            normalItem,
            warningItem
        ])

        try data.write(
            to: testStorage.fileURL,
            options: .atomic
        )

        let loadedItems =
            try ClipboardPersistenceService.loadItems(
                from: testStorage.fileURL
            )

        XCTAssertEqual(loadedItems, [normalItem])
    }

    func testInvalidStoredJSONThrowsAnError() throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        try Data(
            "This is not valid JSON".utf8
        ).write(
            to: testStorage.fileURL,
            options: .atomic
        )

        XCTAssertThrowsError(
            try ClipboardPersistenceService.loadItems(
                from: testStorage.fileURL
            )
        )
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

    private func makeTestStorage(
        createDirectory: Bool = true
    ) throws -> TestStorage {
        let directoryURL =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "ClipVaultPersistenceTests-\(UUID().uuidString)",
                    isDirectory: true
                )

        if createDirectory {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }

        let fileURL = directoryURL.appendingPathComponent(
            "clipboard-history.json"
        )

        return TestStorage(
            directoryURL: directoryURL,
            fileURL: fileURL
        )
    }

    private func removeTestStorage(
        _ testStorage: TestStorage
    ) {
        try? FileManager.default.removeItem(
            at: testStorage.directoryURL
        )
    }
}

private struct TestStorage {
    let directoryURL: URL
    let fileURL: URL
}

