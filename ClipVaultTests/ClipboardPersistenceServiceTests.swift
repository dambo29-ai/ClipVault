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
    
    func testPinnedCopyPreservesItemMetadata() {
        let itemID = UUID()
        let createdAt = date(2026, 7, 10)
        let pinnedAt = date(2026, 7, 15)

        let item = ClipboardItem(
            id: itemID,
            text: "Reusable text",
            createdAt: createdAt,
            sourceAppName: "TextEdit",
            sourceBundleIdentifier:
                "com.apple.TextEdit",
            origin: .restored,
            contentKind: .link
        )

        let pinnedItem =
            item.pinnedCopy(
                pinnedAt: pinnedAt
            )

        XCTAssertEqual(pinnedItem.id, itemID)
        XCTAssertEqual(
            pinnedItem.text,
            "Reusable text"
        )
        XCTAssertEqual(
            pinnedItem.createdAt,
            createdAt
        )
        XCTAssertEqual(
            pinnedItem.sourceAppName,
            "TextEdit"
        )
        XCTAssertEqual(
            pinnedItem.sourceBundleIdentifier,
            "com.apple.TextEdit"
        )
        XCTAssertEqual(
            pinnedItem.origin,
            .restored
        )
        XCTAssertEqual(
            pinnedItem.contentKind,
            .link
        )
        XCTAssertEqual(
            pinnedItem.payload,
            item.payload
        )
        XCTAssertTrue(pinnedItem.isPinned)
        XCTAssertEqual(
            pinnedItem.pinnedAt,
            pinnedAt
        )
    }

    func testUnpinnedCopyPreservesItemMetadataAndClearsPinDate() {
        let itemID = UUID()
        let createdAt = date(2026, 7, 10)

        let pinnedItem = ClipboardItem(
            id: itemID,
            text: "Pinned text",
            createdAt: createdAt,
            sourceAppName: "Notes",
            sourceBundleIdentifier:
                "com.apple.Notes",
            origin: .captured,
            contentKind: .link,
            isPinned: true,
            pinnedAt: date(2026, 7, 15)
        )

        let unpinnedItem =
            pinnedItem.unpinnedCopy()

        XCTAssertEqual(
            unpinnedItem.id,
            itemID
        )
        XCTAssertEqual(
            unpinnedItem.text,
            "Pinned text"
        )
        XCTAssertEqual(
            unpinnedItem.createdAt,
            createdAt
        )
        XCTAssertEqual(
            unpinnedItem.sourceAppName,
            "Notes"
        )
        XCTAssertEqual(
            unpinnedItem.sourceBundleIdentifier,
            "com.apple.Notes"
        )
        XCTAssertEqual(
            unpinnedItem.origin,
            .captured
        )
        XCTAssertEqual(
            unpinnedItem.contentKind,
            .link
        )
        XCTAssertEqual(
            unpinnedItem.payload,
            pinnedItem.payload
        )
        XCTAssertFalse(
            unpinnedItem.isPinned
        )
        XCTAssertNil(
            unpinnedItem.pinnedAt
        )
    }

    func testWarningRowCannotBePinned() {
        let warningItem = ClipboardItem(
            text: "Warning",
            kind: .sensitiveSkipped
        )

        let result =
            warningItem.pinnedCopy(
                pinnedAt: date(2026, 7, 15)
            )

        XCTAssertEqual(
            result,
            warningItem
        )
        XCTAssertFalse(
            result.isPinned
        )
        XCTAssertNil(
            result.pinnedAt
        )
    }
    
    func testTypedPayloadSurvivesPersistence() async throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        let service =
            ClipboardPersistenceService(
                storageURL:
                    testStorage.fileURL
            )

        let originalItem =
            ClipboardItem(
                payload:
                    .link(
                        ClipboardLinkPayload(
                            urlString:
                                "https://example.com/products"
                        )
                    ),
                createdAt:
                    date(2026, 7, 16)
            )

        try await service.saveItems([
            originalItem
        ])

        let loadedItems =
            try await service.loadItems()

        XCTAssertEqual(
            loadedItems,
            [originalItem]
        )

        XCTAssertEqual(
            loadedItems.first?.payload,
            originalItem.payload
        )

        XCTAssertEqual(
            loadedItems.first?.text,
            "https://example.com/products"
        )

        XCTAssertEqual(
            loadedItems.first?.searchableText,
            "https://example.com/products"
        )

        XCTAssertEqual(
            loadedItems.first?.contentKind,
            .link
        )
    }
    
    func testImagePayloadSurvivesPersistence()
        async throws
    {
        let testStorage =
            try makeTestStorage()

        defer {
            removeTestStorage(
                testStorage
            )
        }

        let service =
            ClipboardPersistenceService(
                storageURL:
                    testStorage.fileURL
            )

        let imagePayload =
            ClipboardImagePayload(
                storageIdentifier:
                    UUID(
                        uuidString:
                            "B10C1331-D322-42C6-9254-B488A5262900"
                    )!,
                format:
                    ClipboardImageFormat(
                        uniformTypeIdentifier:
                            "public.png",
                        filenameExtension:
                            "png",
                        displayName:
                            "PNG"
                    ),
                pixelWidth: 1440,
                pixelHeight: 900,
                byteCount: 842_000,
                contentHash:
                    "abcdef123456",
                originalFilename:
                    "source-image.png",
                wasConverted: false
            )

        let originalItem =
            ClipboardItem(
                payload:
                    .image(
                        imagePayload
                    ),
                createdAt:
                    date(
                        2026,
                        7,
                        16
                    ),
                sourceAppName:
                    "Safari",
                sourceBundleIdentifier:
                    "com.apple.Safari"
            )

        try await service.saveItems([
            originalItem
        ])

        let loadedItems =
            try await service.loadItems()

        XCTAssertEqual(
            loadedItems,
            [originalItem]
        )

        XCTAssertEqual(
            loadedItems.first?.contentKind,
            .image
        )

        XCTAssertEqual(
            loadedItems.first?.imagePayload,
            imagePayload
        )

        XCTAssertEqual(
            loadedItems.first?.displayText,
            "source-image.png"
        )

        XCTAssertEqual(
            loadedItems.first?.duplicateKey,
            "image:abcdef123456"
        )
    }
    
    func testCustomTitleSurvivesPersistence()
        async throws
    {
        let testStorage =
            try makeTestStorage()

        defer {
            removeTestStorage(
                testStorage
            )
        }

        let service =
            ClipboardPersistenceService(
                storageURL:
                    testStorage.fileURL
            )

        let originalItem =
            ClipboardItem(
                text:
                    "https://www.youtube.com/watch?v=example",
                contentKind:
                    .link,
                customTitle:
                    "Video - Dance Choreography"
            )

        try await service.saveItems([
            originalItem
        ])

        let loadedItems =
            try await service.loadItems()

        XCTAssertEqual(
            loadedItems,
            [originalItem]
        )

        XCTAssertEqual(
            loadedItems.first?
                .customTitle,
            "Video - Dance Choreography"
        )
    }

    func testRenamedCopyPreservesUnderlyingPayload()
    {
        let originalItem =
            ClipboardItem(
                text:
                    "https://www.adidas.com/product",
                contentKind:
                    .link
            )

        let renamedItem =
            originalItem.renamedCopy(
                customTitle:
                    "Sambas in Black"
            )

        XCTAssertEqual(
            renamedItem.customTitle,
            "Sambas in Black"
        )

        XCTAssertEqual(
            renamedItem.payload,
            originalItem.payload
        )

        XCTAssertEqual(
            renamedItem.text,
            originalItem.text
        )

        XCTAssertEqual(
            renamedItem.duplicateKey,
            originalItem.duplicateKey
        )
    }

    func testEmptyCustomTitleRestoresAutomaticTitle()
    {
        let originalItem =
            ClipboardItem(
                text:
                    "https://example.com",
                contentKind:
                    .link,
                customTitle:
                    "Example Website"
            )

        let renamedItem =
            originalItem.renamedCopy(
                customTitle:
                    "   \n "
            )

        XCTAssertNil(
            renamedItem.customTitle
        )

        XCTAssertEqual(
            renamedItem.displayText,
            "https://example.com"
        )
    }

    func testCustomTitleIsSearchableAlongsidePayload()
    {
        let item =
            ClipboardItem(
                text:
                    "https://www.youtube.com/watch?v=example",
                contentKind:
                    .link,
                customTitle:
                    "Britain's Got Talent"
            )

        XCTAssertTrue(
            item.searchableText
                .localizedCaseInsensitiveContains(
                    "Britain"
                )
        )

        XCTAssertTrue(
            item.searchableText
                .localizedCaseInsensitiveContains(
                    "youtube"
                )
        )
    }

    func testPinAndUnpinPreserveCustomTitle()
    {
        let item =
            ClipboardItem(
                text:
                    "Original content",
                customTitle:
                    "My Useful Clip"
            )

        let pinnedItem =
            item.pinnedCopy()

        let unpinnedItem =
            pinnedItem.unpinnedCopy()

        XCTAssertEqual(
            pinnedItem.customTitle,
            "My Useful Clip"
        )

        XCTAssertEqual(
            unpinnedItem.customTitle,
            "My Useful Clip"
        )
    }

    func testEncodedItemContainsPayloadAndLegacyTextFields() throws {
        let item =
            ClipboardItem(
                payload:
                    .text(
                        ClipboardTextPayload(
                            text:
                                "Compatibility text"
                        )
                    )
            )

        let encodedData =
            try JSONEncoder().encode(
                item
            )

        let jsonObject =
            try JSONSerialization.jsonObject(
                with: encodedData
            )

        guard
            let dictionary =
                jsonObject as? [String: Any]
        else {
            XCTFail(
                "Expected an encoded item dictionary."
            )
            return
        }

        XCTAssertNotNil(
            dictionary["payload"]
        )

        XCTAssertEqual(
            dictionary["text"] as? String,
            "Compatibility text"
        )

        XCTAssertEqual(
            dictionary["contentKind"] as? String,
            "text"
        )
    }

    func testPayloadTakesPriorityOverLegacyCompatibilityFields() throws {
        let itemID = UUID()

        let storedJSON = """
        {
          "id": "\(itemID.uuidString)",
          "payload": {
            "link": {
              "_0": {
                "urlString": "https://payload.example.com"
              }
            }
          },
          "text": "Legacy conflicting text",
          "createdAt": 599572800,
          "kind": "normal",
          "sourceAppName": null,
          "sourceBundleIdentifier": null,
          "origin": "captured",
          "contentKind": "text",
          "isPinned": false,
          "pinnedAt": null
        }
        """

        let decodedItem =
            try JSONDecoder().decode(
                ClipboardItem.self,
                from: Data(storedJSON.utf8)
            )

        XCTAssertEqual(
            decodedItem.payload,
            .link(
                ClipboardLinkPayload(
                    urlString:
                        "https://payload.example.com"
                )
            )
        )

        XCTAssertEqual(
            decodedItem.text,
            "https://payload.example.com"
        )

        XCTAssertEqual(
            decodedItem.contentKind,
            .link
        )
    }
    
    func testContentKindSurvivesPersistence() async throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        let service = ClipboardPersistenceService(
            storageURL: testStorage.fileURL
        )

        let linkItem = ClipboardItem(
            text: "https://example.com",
            contentKind: .link
        )

        try await service.saveItems([
            linkItem
        ])

        let loadedItems =
            try await service.loadItems()

        XCTAssertEqual(loadedItems.count, 1)
        XCTAssertEqual(
            loadedItems.first?.contentKind,
            .link
        )
        XCTAssertEqual(
            loadedItems.first,
            linkItem
        )
    }

    func testNewNormalItemsInferLinkContentKind() {
        let item = ClipboardItem(
            text: "https://example.com/path"
        )

        XCTAssertEqual(
            item.contentKind,
            .link
        )
    }

    func testNewNormalItemsInferTextContentKind() {
        let item = ClipboardItem(
            text: "Ordinary clipboard text"
        )

        XCTAssertEqual(
            item.contentKind,
            .text
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
            loadedItems.first?.contentKind,
            .text
        )

        XCTAssertEqual(
            loadedItems.first?.isPinned,
            false
        )

        XCTAssertNil(
            loadedItems.first?.pinnedAt
        )
    }
    
    func testLegacySavedLinkWithoutContentKindDecodesAsLink() throws {
        let testStorage = try makeTestStorage()
        defer {
            removeTestStorage(testStorage)
        }

        let itemID = UUID()

        let storedJSON = """
        [
          {
            "id": "\(itemID.uuidString)",
            "text": "https://example.com",
            "createdAt": 599572800,
            "kind": "normal",
            "sourceAppName": null,
            "sourceBundleIdentifier": null,
            "origin": "captured",
            "isPinned": false,
            "pinnedAt": null
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
            loadedItems.first?.contentKind,
            .link
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

