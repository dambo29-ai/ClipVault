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
    func testNormalMergeImportsNewItemsAndPreservesExistingItems() {
        let existingItem = makeItem(
            text: "Existing clip",
            createdAt: date(2026, 7, 10)
        )

        let backupItem = makeItem(
            text: "Imported clip",
            createdAt: date(2026, 7, 9)
        )

        let result = ClipboardImportService.prepareImport(
            existingItems: [existingItem],
            backupItems: [backupItem],
            maximumItemCount: 10
        )

        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.duplicateCount, 0)
        XCTAssertEqual(result.skippedDueToLimitCount, 0)
        XCTAssertEqual(result.mergedItems.count, 2)

        XCTAssertTrue(
            result.mergedItems.contains {
                $0.text == "Existing clip"
            }
        )

        XCTAssertTrue(
            result.mergedItems.contains {
                $0.text == "Imported clip"
            }
        )
    }

    func testImportedItemsAreMarkedAsRestored() {
        let backupItem = makeItem(
            text: "Historical clip",
            createdAt: date(2020, 1, 1)
        )

        let result = ClipboardImportService.prepareImport(
            existingItems: [],
            backupItems: [backupItem],
            maximumItemCount: 10
        )

        XCTAssertEqual(result.importedCount, 1)

        let importedItem = try? XCTUnwrap(
            result.mergedItems.first
        )

        XCTAssertEqual(
            importedItem?.origin,
            .restored
        )

        XCTAssertEqual(
            importedItem?.createdAt,
            backupItem.createdAt
        )
    }

    func testExistingHistoryDuplicateIsSkipped() {
        let existingItem = makeItem(
            text: "Duplicate clip"
        )

        let backupItem = makeItem(
            text: "Duplicate clip"
        )

        let result = ClipboardImportService.prepareImport(
            existingItems: [existingItem],
            backupItems: [backupItem],
            maximumItemCount: 10
        )

        XCTAssertEqual(result.importedCount, 0)
        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertEqual(result.mergedItems, [existingItem])
    }

    func testDuplicateWithinBackupIsSkipped() {
        let firstBackupItem = makeItem(
            text: "Repeated backup clip",
            createdAt: date(2026, 7, 10)
        )

        let secondBackupItem = makeItem(
            text: "Repeated backup clip",
            createdAt: date(2026, 7, 9)
        )

        let result = ClipboardImportService.prepareImport(
            existingItems: [],
            backupItems: [
                firstBackupItem,
                secondBackupItem
            ],
            maximumItemCount: 10
        )

        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertEqual(result.mergedItems.count, 1)
    }

    func testDuplicateComparisonUsesTrimmedText() {
        let existingItem = makeItem(
            text: "Trimmed duplicate"
        )

        let backupItem = makeItem(
            text: "  Trimmed duplicate\n"
        )

        let result = ClipboardImportService.prepareImport(
            existingItems: [existingItem],
            backupItems: [backupItem],
            maximumItemCount: 10
        )

        XCTAssertEqual(result.importedCount, 0)
        XCTAssertEqual(result.duplicateCount, 1)
    }

    func testWarningRowsDoNotConsumeHistoryCapacity() {
        let existingNormalItems = (1...8).map {
            makeItem(
                text: "Existing \($0)",
                createdAt: date(2026, 7, $0)
            )
        }

        let warningItem = makeItem(
            text: "Warning",
            kind: .sensitiveSkipped
        )

        let backupItems = [
            makeItem(text: "Imported 1"),
            makeItem(text: "Imported 2")
        ]

        let result = ClipboardImportService.prepareImport(
            existingItems: existingNormalItems + [warningItem],
            backupItems: backupItems,
            maximumItemCount: 10
        )

        XCTAssertEqual(result.importedCount, 2)
        XCTAssertEqual(result.skippedDueToLimitCount, 0)

        let normalItemCount = result.mergedItems.filter {
            $0.kind == .normal
        }.count

        XCTAssertEqual(normalItemCount, 10)
        XCTAssertTrue(
            result.mergedItems.contains(warningItem)
        )
    }

    func testImportThatExactlyReachesLimitSucceeds() {
        let existingItems = (1...8).map {
            makeItem(text: "Existing \($0)")
        }

        let backupItems = [
            makeItem(text: "Imported 1"),
            makeItem(text: "Imported 2")
        ]

        let result = ClipboardImportService.prepareImport(
            existingItems: existingItems,
            backupItems: backupItems,
            maximumItemCount: 10
        )

        XCTAssertEqual(result.importedCount, 2)
        XCTAssertEqual(result.skippedDueToLimitCount, 0)
        XCTAssertEqual(
            result.mergedItems.filter {
                $0.kind == .normal
            }.count,
            10
        )
    }

    func testOverLimitImportDoesNotMutateExistingHistory() {
        let existingItems = (1...10).map {
            makeItem(text: "Existing \($0)")
        }

        let backupItem = makeItem(
            text: "Too many"
        )

        let result = ClipboardImportService.prepareImport(
            existingItems: existingItems,
            backupItems: [backupItem],
            maximumItemCount: 10
        )

        XCTAssertEqual(result.importedCount, 0)
        XCTAssertEqual(result.skippedDueToLimitCount, 1)
        XCTAssertEqual(result.mergedItems, existingItems)
    }

    func testReplacementRemovesDuplicatesAndMarksItemsRestored() {
        let newerItem = makeItem(
            text: "Newer",
            createdAt: date(2026, 7, 10)
        )

        let olderDuplicate = makeItem(
            text: "Newer",
            createdAt: date(2026, 7, 1)
        )

        let secondItem = makeItem(
            text: "Second",
            createdAt: date(2026, 7, 5)
        )

        let result = ClipboardImportService.prepareReplacement(
            backupItems: [
                newerItem,
                olderDuplicate,
                secondItem
            ],
            maximumItemCount: 10
        )

        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertEqual(result.skippedDueToLimitCount, 0)
        XCTAssertEqual(result.replacementItems.count, 2)

        XCTAssertTrue(
            result.replacementItems.allSatisfy {
                $0.origin == .restored
            }
        )
    }

    func testReplacementSortsNewestFirst() {
        let olderItem = makeItem(
            text: "Older",
            createdAt: date(2020, 1, 1)
        )

        let newerItem = makeItem(
            text: "Newer",
            createdAt: date(2026, 1, 1)
        )

        let result = ClipboardImportService.prepareReplacement(
            backupItems: [
                olderItem,
                newerItem
            ],
            maximumItemCount: 10
        )

        XCTAssertEqual(
            result.replacementItems.map(\.text),
            ["Newer", "Older"]
        )
    }

    func testReplacementTrimsToHistoryLimit() {
        let backupItems = (1...12).map {
            makeItem(
                text: "Backup \($0)",
                createdAt: date(2026, 7, $0)
            )
        }

        let result = ClipboardImportService.prepareReplacement(
            backupItems: backupItems,
            maximumItemCount: 10
        )

        XCTAssertEqual(result.replacementItems.count, 10)
        XCTAssertEqual(result.skippedDueToLimitCount, 2)
    }

    func testNonNormalBackupItemsAreIgnored() {
        let normalItem = makeItem(
            text: "Normal"
        )

        let warningItem = makeItem(
            text: "Warning",
            kind: .sensitiveSkipped
        )

        let result = ClipboardImportService.prepareImport(
            existingItems: [],
            backupItems: [
                normalItem,
                warningItem
            ],
            maximumItemCount: 10
        )

        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(
            result.mergedItems.filter {
                $0.kind == .normal
            }.count,
            1
        )

        XCTAssertFalse(
            result.mergedItems.contains {
                $0.kind == .sensitiveSkipped
            }
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

    func testVersionOneBackupWithoutOriginStillImports() throws {
        let backupURL = try makeTemporaryBackupFile(
            appName: "ClipVault",
            formatVersion: 1,
            itemJSON: """
            {
              "id": "\(UUID().uuidString)",
              "text": "Legacy backup clip",
              "createdAt": "2020-01-01T12:00:00Z",
              "kind": "normal",
              "sourceAppName": null,
              "sourceBundleIdentifier": null
            }
            """
        )

        defer {
            try? FileManager.default.removeItem(
                at: backupURL
            )
        }

        let items = try ClipboardImportService.itemsFromJSONBackup(
            at: backupURL
        )

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.text, "Legacy backup clip")

        let result = ClipboardImportService.prepareImport(
            existingItems: [],
            backupItems: items,
            maximumItemCount: 10
        )

        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(
            result.mergedItems.first?.origin,
            .restored
        )
    }

    func testMalformedJSONReturnsInvalidBackupError() throws {
        let fileURL = try makeTemporaryFile(
            filename: "Malformed.json",
            contents: """
            {
              "appName": "ClipVault",
              "formatVersion": 1,
              "items":
            """
        )

        defer {
            try? FileManager.default.removeItem(
                at: fileURL
            )
        }

        XCTAssertThrowsError(
            try ClipboardImportService.itemsFromJSONBackup(
                at: fileURL
            )
        ) { error in
            guard let importError =
                error as? ClipboardImportError else {
                return XCTFail(
                    "Expected ClipboardImportError but received \(error)"
                )
            }

            XCTAssertEqual(
                importError,
                .invalidClipVaultBackup
            )

            XCTAssertEqual(
                importError.errorDescription,
                "This JSON file is not a valid ClipVault backup."
            )
        }
    }

    func testNonJSONFileReturnsInvalidFileTypeError() throws {
        let fileURL = try makeTemporaryFile(
            filename: "NotABackup.txt",
            contents: "Not a ClipVault backup"
        )

        defer {
            try? FileManager.default.removeItem(
                at: fileURL
            )
        }

        XCTAssertThrowsError(
            try ClipboardImportService.itemsFromJSONBackup(
                at: fileURL
            )
        ) { error in
            guard let importError =
                error as? ClipboardImportError else {
                return XCTFail(
                    "Expected ClipboardImportError but received \(error)"
                )
            }

            XCTAssertEqual(
                importError,
                .invalidFileType
            )

            XCTAssertEqual(
                importError.errorDescription,
                "Please select a ClipVault JSON backup file."
            )
        }
    }

    func testInvalidBackupAppNameIsRejected() throws {
        let backupURL = try makeTemporaryBackupFile(
            appName: "AnotherApp",
            formatVersion: 1,
            itemJSON: """
            {
              "id": "\(UUID().uuidString)",
              "text": "Wrong app",
              "createdAt": "2020-01-01T12:00:00Z",
              "kind": "normal",
              "sourceAppName": null,
              "sourceBundleIdentifier": null
            }
            """
        )

        defer {
            try? FileManager.default.removeItem(
                at: backupURL
            )
        }

        XCTAssertThrowsError(
            try ClipboardImportService.itemsFromJSONBackup(
                at: backupURL
            )
        ) { error in
            guard let exportError =
                error as? ClipboardHistoryExportError else {
                return XCTFail(
                    "Expected ClipboardHistoryExportError but received \(error)"
                )
            }

            XCTAssertEqual(
                exportError,
                .invalidBackupAppName
            )
        }
    }

    func testUnsupportedBackupVersionIsRejected() throws {
        let backupURL = try makeTemporaryBackupFile(
            appName: "ClipVault",
            formatVersion: 999,
            itemJSON: """
            {
              "id": "\(UUID().uuidString)",
              "text": "Future backup",
              "createdAt": "2020-01-01T12:00:00Z",
              "kind": "normal",
              "sourceAppName": null,
              "sourceBundleIdentifier": null
            }
            """
        )

        defer {
            try? FileManager.default.removeItem(
                at: backupURL
            )
        }

        XCTAssertThrowsError(
            try ClipboardImportService.itemsFromJSONBackup(
                at: backupURL
            )
        ) { error in
            guard let exportError =
                error as? ClipboardHistoryExportError else {
                return XCTFail(
                    "Expected ClipboardHistoryExportError but received \(error)"
                )
            }

            XCTAssertEqual(
                exportError,
                .unsupportedBackupFormat
            )
        }
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

    private func makeTemporaryBackupFile(
        appName: String,
        formatVersion: Int,
        itemJSON: String
    ) throws -> URL {
        let json = """
        {
          "appName": "\(appName)",
          "formatVersion": \(formatVersion),
          "exportedAt": "2026-07-12T12:00:00Z",
          "items": [
            \(itemJSON)
          ]
        }
        """

        return try makeTemporaryFile(
            filename: "\(UUID().uuidString).json",
            contents: json
        )
    }

    private func makeTemporaryFile(
        filename: String,
        contents: String
    ) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ClipVaultTests-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileURL = directoryURL.appendingPathComponent(
            filename
        )

        try Data(contents.utf8).write(
            to: fileURL,
            options: .atomic
        )

        return fileURL
    }
}


