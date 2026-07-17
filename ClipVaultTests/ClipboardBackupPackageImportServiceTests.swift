//
//  ClipboardBackupPackageImportServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/17/26.
//

import AppKit
import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardBackupPackageImportServiceTests {
    @Test
    func readsValidTextOnlyPackage()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            text:
                                "Restored text"
                        )
                    ]
                )

        let contents =
            try context
                .importService
                .readPackage(
                    at:
                        packageURL
                )

        #expect(
            contents.manifest.items.count ==
                1
        )

        #expect(
            contents.manifest.items.first?
                .text ==
                "Restored text"
        )

        #expect(
            contents
                .imageDataByStorageIdentifier
                .isEmpty
        )
    }

    @Test
    func readsAndValidatesImageAsset()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let imageData =
            try makePNGData(
                width:
                    12,
                height:
                    9
            )

        let imagePayload =
            try await context
                .imageStorageService
                .storeImage(
                    data:
                        imageData,
                    originalFilename:
                        "family.png"
                )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            payload:
                                .image(
                                    imagePayload
                                )
                        )
                    ]
                )

        let contents =
            try context
                .importService
                .readPackage(
                    at:
                        packageURL
                )

        #expect(
            contents
                .imageDataByStorageIdentifier[
                    imagePayload
                        .storageIdentifier
                ] ==
                imageData
        )
    }

    @Test
    func warningItemsAreExcludedFromImportedContents()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            text:
                                "Normal"
                        ),
                        ClipboardItem(
                            text:
                                "Warning",
                            kind:
                                .sensitiveSkipped
                        )
                    ]
                )

        let contents =
            try context
                .importService
                .readPackage(
                    at:
                        packageURL
                )

        #expect(
            contents.manifest.items.count ==
                1
        )

        #expect(
            contents.manifest.items.first?
                .text ==
                "Normal"
        )
    }

    @Test
    func missingManifestIsRejected()
        throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let packageURL =
            context.exportsDirectory
                .appendingPathComponent(
                    "Missing Manifest"
                )
                .appendingPathExtension(
                    "clipvaultbackup"
                )

        try FileManager.default
            .createDirectory(
                at:
                    packageURL,
                withIntermediateDirectories:
                    true
            )

        do {
            _ =
                try context
                    .importService
                    .readPackage(
                        at:
                            packageURL
                    )

            Issue.record(
                "Expected a missing manifest to be rejected."
            )
        } catch let error
            as ClipboardBackupPackageImportError
        {
            #expect(
                error ==
                    .manifestMissing
            )
        }
    }

    @Test
    func incorrectFileExtensionIsRejected()
        throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let invalidURL =
            context.testRoot
                .appendingPathComponent(
                    "Backup.json"
                )

        try FileManager.default
            .createDirectory(
                at:
                    context.testRoot,
                withIntermediateDirectories:
                    true
            )

        try Data()
            .write(
                to:
                    invalidURL
            )

        do {
            _ =
                try context
                    .importService
                    .readPackage(
                        at:
                            invalidURL
                    )

            Issue.record(
                "Expected an incorrect extension to be rejected."
            )
        } catch let error
            as ClipboardBackupPackageImportError
        {
            #expect(
                error ==
                    .invalidPackageExtension
            )
        }
    }

    @Test
    func missingImageAssetIsRejected()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let imagePayload =
            try await context
                .imageStorageService
                .storeImage(
                    data:
                        makePNGData(
                            width:
                                6,
                            height:
                                6
                        )
                )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            payload:
                                .image(
                                    imagePayload
                                )
                        )
                    ]
                )

        let packagedImageURL =
            packageURL
                .appendingPathComponent(
                    "Images",
                    isDirectory:
                        true
                )
                .appendingPathComponent(
                    imagePayload
                        .storedFilename
                )

        try FileManager.default
            .removeItem(
                at:
                    packagedImageURL
            )

        do {
            _ =
                try context
                    .importService
                    .readPackage(
                        at:
                            packageURL
                    )

            Issue.record(
                "Expected a missing image asset to be rejected."
            )
        } catch let error
            as ClipboardBackupPackageImportError
        {
            #expect(
                error ==
                    .missingImageAsset(
                        filename:
                            imagePayload
                                .storedFilename
                    )
            )
        }
    }

    @Test
    func corruptedImageAssetIsRejected()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let imagePayload =
            try await context
                .imageStorageService
                .storeImage(
                    data:
                        makePNGData(
                            width:
                                7,
                            height:
                                5
                        )
                )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            payload:
                                .image(
                                    imagePayload
                                )
                        )
                    ]
                )

        let packagedImageURL =
            packageURL
                .appendingPathComponent(
                    "Images",
                    isDirectory:
                        true
                )
                .appendingPathComponent(
                    imagePayload
                        .storedFilename
                )

        try Data(
            "Damaged image data"
                .utf8
        )
        .write(
            to:
                packagedImageURL,
            options:
                [.atomic]
        )

        do {
            _ =
                try context
                    .importService
                    .readPackage(
                        at:
                            packageURL
                    )

            Issue.record(
                "Expected a corrupted image asset to be rejected."
            )
        } catch let error
            as ClipboardBackupPackageImportError
        {
            #expect(
                error ==
                    .corruptedImageAsset(
                        filename:
                            imagePayload
                                .storedFilename
                    )
            )
        }
    }
    
    @Test
    func restoresTextItemWithRestoredOrigin()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let originalItem =
            ClipboardItem(
                text:
                    "Restored text",
                sourceAppName:
                    "Notes",
                sourceBundleIdentifier:
                    "com.apple.Notes",
                isPinned:
                    true,
                pinnedAt:
                    Date(
                        timeIntervalSince1970:
                            1_700_000_000
                    )
            )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        originalItem
                    ]
                )

        let contents =
            try context
                .importService
                .readPackage(
                    at:
                        packageURL
                )

        let restoration =
            try await context
                .importService
                .restorePackage(
                    contents
                )

        #expect(
            restoration.items.count ==
                1
        )

        let restoredItem =
            try #require(
                restoration.items.first
            )

        #expect(
            restoredItem.id ==
                originalItem.id
        )

        #expect(
            restoredItem.text ==
                originalItem.text
        )

        #expect(
            restoredItem.origin ==
                .restored
        )

        #expect(
            restoredItem.isPinned
        )

        #expect(
            restoration
                .restoredImagePayloads
                .isEmpty
        )
    }
    
    @Test
    func restoresImageIntoManagedStorageWithNewIdentifier()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let imageData =
            try makePNGData(
                width:
                    11,
                height:
                    8
            )

        let originalPayload =
            try await context
                .imageStorageService
                .storeImage(
                    data:
                        imageData,
                    originalFilename:
                        "vacation.png",
                    wasConverted:
                        true
                )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            payload:
                                .image(
                                    originalPayload
                                )
                        )
                    ]
                )

        let contents =
            try context
                .importService
                .readPackage(
                    at:
                        packageURL
                )

        let restoration =
            try await context
                .importService
                .restorePackage(
                    contents
                )

        let restoredItem =
            try #require(
                restoration.items.first
            )

        let restoredPayload =
            try #require(
                restoredItem.imagePayload
            )

        #expect(
            restoredPayload
                .storageIdentifier !=
            originalPayload
                .storageIdentifier
        )

        #expect(
            restoredPayload.contentHash ==
                originalPayload.contentHash
        )

        #expect(
            restoredPayload.originalFilename ==
                "vacation.png"
        )

        #expect(
            restoredPayload.wasConverted
        )

        #expect(
            restoration
                .restoredImagePayloads ==
                [
                    restoredPayload
                ]
        )

        let restoredData =
            try await context
                .restoredImageStorageService
                .loadImageData(
                    for:
                        restoredPayload
                )

        #expect(
            restoredData ==
                imageData
        )
    }
    
    @Test
    func sharedImageAssetIsRestoredOnlyOnce()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let originalPayload =
            try await context
                .imageStorageService
                .storeImage(
                    data:
                        makePNGData(
                            width:
                                9,
                            height:
                                9
                        )
                )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            id:
                                UUID(),
                            payload:
                                .image(
                                    originalPayload
                                )
                        ),
                        ClipboardItem(
                            id:
                                UUID(),
                            payload:
                                .image(
                                    originalPayload
                                )
                        )
                    ]
                )

        let contents =
            try context
                .importService
                .readPackage(
                    at:
                        packageURL
                )

        let restoration =
            try await context
                .importService
                .restorePackage(
                    contents
                )

        #expect(
            restoration.items.count ==
                2
        )

        #expect(
            restoration
                .restoredImagePayloads
                .count ==
                1
        )

        let firstPayload =
            try #require(
                restoration.items[0]
                    .imagePayload
            )

        let secondPayload =
            try #require(
                restoration.items[1]
                    .imagePayload
            )

        #expect(
            firstPayload
                .storageIdentifier ==
            secondPayload
                .storageIdentifier
        )
    }
    
    @Test
    func restorationFailureRollsBackNewImageAssets()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let validPayload =
            try await context
                .imageStorageService
                .storeImage(
                    data:
                        makePNGData(
                            width:
                                10,
                            height:
                                6
                        )
                )

        let missingPayload =
            ClipboardImagePayload(
                storageIdentifier:
                    UUID(),
                format:
                    validPayload.format,
                pixelWidth:
                    validPayload.pixelWidth,
                pixelHeight:
                    validPayload.pixelHeight,
                byteCount:
                    validPayload.byteCount,
                contentHash:
                    validPayload.contentHash,
                originalFilename:
                    "missing.png",
                wasConverted:
                    false
            )

        let contents =
            ClipboardBackupPackageContents(
                packageURL:
                    context.testRoot,
                manifest:
                    ClipboardBackupPackageManifest(
                        appName:
                            "ClipVault",
                        formatVersion:
                            ClipboardBackupPackageService
                                .currentFormatVersion,
                        exportedAt:
                            Date(),
                        items: [
                            ClipboardItem(
                                payload:
                                    .image(
                                        validPayload
                                    )
                            ),
                            ClipboardItem(
                                payload:
                                    .image(
                                        missingPayload
                                    )
                            )
                        ]
                    ),
                imageDataByStorageIdentifier: [
                    validPayload
                        .storageIdentifier:
                        try makePNGData(
                            width:
                                10,
                            height:
                                6
                        )
                ]
            )

        do {
            _ =
                try await context
                    .importService
                    .restorePackage(
                        contents
                    )

            Issue.record(
                "Expected restoration to fail when validated image data is missing."
            )
        } catch let error
            as ClipboardBackupPackageImportError
        {
            #expect(
                error ==
                    .missingValidatedImageData(
                        storageIdentifier:
                            missingPayload
                                .storageIdentifier
                    )
            )
        }

        let restoredFiles =
            (
                try? FileManager.default
                    .contentsOfDirectory(
                        at:
                            context
                                .restoredImagesDirectory,
                        includingPropertiesForKeys:
                            nil
                    )
            ) ?? []

        #expect(
            restoredFiles.isEmpty
        )
    }
    
    @Test
    func unretainedRestoredImageAssetIsDeleted()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let originalPayload =
            try await context
                .imageStorageService
                .storeImage(
                    data:
                        makePNGData(
                            width: 8,
                            height: 7
                        )
                )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            payload:
                                .image(
                                    originalPayload
                                )
                        )
                    ]
                )

        let contents =
            try context
                .importService
                .readPackage(
                    at:
                        packageURL
                )

        let restoration =
            try await context
                .importService
                .restorePackage(
                    contents
                )

        let restoredPayload =
            try #require(
                restoration
                    .restoredImagePayloads
                    .first
            )

        _ =
            try await context
                .restoredImageStorageService
                .loadImageData(
                    for:
                        restoredPayload
                )

        await context
            .importService
            .deleteUnretainedRestoredImageAssets(
                from:
                    restoration,
                retainedItems: []
            )

        do {
            _ =
                try await context
                    .restoredImageStorageService
                    .loadImageData(
                        for:
                            restoredPayload
                    )

            Issue.record(
                "Expected the unretained restored image asset to be deleted."
            )
        } catch {
            // Expected.
        }
    }
    
    @Test
    func retainedRestoredImageAssetIsPreserved()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let originalPayload =
            try await context
                .imageStorageService
                .storeImage(
                    data:
                        makePNGData(
                            width: 9,
                            height: 6
                        )
                )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            payload:
                                .image(
                                    originalPayload
                                )
                        )
                    ]
                )

        let contents =
            try context
                .importService
                .readPackage(
                    at:
                        packageURL
                )

        let restoration =
            try await context
                .importService
                .restorePackage(
                    contents
                )

        let restoredItem =
            try #require(
                restoration.items.first
            )

        let restoredPayload =
            try #require(
                restoredItem.imagePayload
            )

        await context
            .importService
            .deleteUnretainedRestoredImageAssets(
                from:
                    restoration,
                retainedItems: [
                    restoredItem
                ]
            )

        _ =
            try await context
                .restoredImageStorageService
                .loadImageData(
                    for:
                        restoredPayload
                )
    }

    private func makeContext()
        -> TestContext
    {
        let testRoot =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "ClipboardBackupPackageImportServiceTests-" +
                    UUID().uuidString,
                    isDirectory:
                        true
                )

        let exportsDirectory =
            testRoot
                .appendingPathComponent(
                    "Exports",
                    isDirectory:
                        true
                )

        let sourceImagesDirectory =
            testRoot
                .appendingPathComponent(
                    "Source Managed Images",
                    isDirectory:
                        true
                )

        let restoredImagesDirectory =
            testRoot
                .appendingPathComponent(
                    "Restored Managed Images",
                    isDirectory:
                        true
                )

        let imageStorageService =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    sourceImagesDirectory
            )

        let restoredImageStorageService =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    restoredImagesDirectory
            )
        let packageService =
            ClipboardBackupPackageService(
                exportsDirectoryURL:
                    exportsDirectory,
                imageStorageService:
                    imageStorageService
            )

        return TestContext(
            testRoot:
                testRoot,
            exportsDirectory:
                exportsDirectory,
            restoredImagesDirectory:
                restoredImagesDirectory,
            imageStorageService:
                imageStorageService,
            restoredImageStorageService:
                restoredImageStorageService,
            packageService:
                packageService,
            importService:
                ClipboardBackupPackageImportService(
                    restoringInto:
                        restoredImageStorageService
                )
        )
    }

    private func removeTestDirectory(
        _ directoryURL: URL
    ) {
        try? FileManager.default
            .removeItem(
                at:
                    directoryURL
            )
    }

    private func makePNGData(
        width: Int,
        height: Int
    ) throws -> Data {
        let image =
            NSImage(
                size:
                    NSSize(
                        width:
                            width,
                        height:
                            height
                    )
            )

        image.lockFocus()

        NSColor.white.setFill()

        NSRect(
            x: 0,
            y: 0,
            width:
                width,
            height:
                height
        )
        .fill()

        image.unlockFocus()

        guard
            let tiffData =
                image.tiffRepresentation,
            let bitmap =
                NSBitmapImageRep(
                    data:
                        tiffData
                ),
            let pngData =
                bitmap.representation(
                    using:
                        .png,
                    properties:
                        [:]
                )
        else {
            throw TestImageError
                .couldNotCreatePNG
        }

        return pngData
    }

    private struct TestContext {
        let testRoot: URL
        let exportsDirectory: URL
        let restoredImagesDirectory: URL

        let imageStorageService:
            ClipboardImageStorageService

        let restoredImageStorageService:
            ClipboardImageStorageService

        let packageService:
            ClipboardBackupPackageService

        let importService:
            ClipboardBackupPackageImportService
    }

    private enum TestImageError:
        Error
    {
        case couldNotCreatePNG
    }
}
