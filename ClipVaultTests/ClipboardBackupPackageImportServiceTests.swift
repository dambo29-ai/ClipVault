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
    func emptyFilesPayloadIsRejected()
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
                            payload:
                                .files(
                                    ClipboardFilesPayload(
                                        files: []
                                    )
                                )
                        )
                    ]
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
                "Expected an empty Files payload to be rejected."
            )
        } catch let error
            as ClipboardBackupPackageImportError
        {
            #expect(
                error ==
                    .invalidFileReference
            )
        }
    }
    
    @Test
    func ordinaryFileReferenceWithoutBookmarkIsRejected()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let reference =
            ClipboardFileReference(
                path:
                    context.testRoot
                        .appendingPathComponent(
                            "Document.txt"
                        )
                        .path,
                displayName:
                    "Document.txt",
                isDirectory:
                    false,
                byteCount:
                    100,
                bookmarkData:
                    nil
            )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            payload:
                                .files(
                                    ClipboardFilesPayload(
                                        files: [
                                            reference
                                        ]
                                    )
                                )
                        )
                    ]
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
                "Expected an ordinary File reference without a bookmark to be rejected."
            )
        } catch let error
            as ClipboardBackupPackageImportError
        {
            #expect(
                error ==
                    .invalidFileReference
            )
        }
    }
    
    @Test
    func partialSymbolicLinkMetadataIsRejected()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let reference =
            ClipboardFileReference(
                path:
                    context.testRoot
                        .appendingPathComponent(
                            "Photo Link"
                        )
                        .path,
                displayName:
                    "Photo Link",
                isDirectory:
                    false,
                byteCount:
                    nil,
                bookmarkData:
                    nil,
                symbolicLinkIdentifier:
                    UUID(),
                symbolicLinkDestination:
                    nil
            )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            payload:
                                .files(
                                    ClipboardFilesPayload(
                                        files: [
                                            reference
                                        ]
                                    )
                                )
                        )
                    ]
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
                "Expected partial symbolic-link metadata to be rejected."
            )
        } catch let error
            as ClipboardBackupPackageImportError
        {
            #expect(
                error ==
                    .invalidFileReference
            )
        }
    }
    
    @Test
    func symbolicLinkWithBookmarkIsRejected()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let reference =
            ClipboardFileReference(
                path:
                    context.testRoot
                        .appendingPathComponent(
                            "Photo Link"
                        )
                        .path,
                displayName:
                    "Photo Link",
                isDirectory:
                    false,
                byteCount:
                    nil,
                bookmarkData:
                    Data([
                        1,
                        2,
                        3
                    ]),
                symbolicLinkIdentifier:
                    UUID(),
                symbolicLinkDestination:
                    "../Pictures/Photo.png"
            )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            payload:
                                .files(
                                    ClipboardFilesPayload(
                                        files: [
                                            reference
                                        ]
                                    )
                                )
                        )
                    ]
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
                "Expected a symbolic link containing bookmark data to be rejected."
            )
        } catch let error
            as ClipboardBackupPackageImportError
        {
            #expect(
                error ==
                    .invalidFileReference
            )
        }
    }
    
    @Test
    func invalidFileReferenceIsRejectedBeforeImageRestoration()
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
                                11,
                            height:
                                8
                        ),
                    originalFilename:
                        "Valid Image.png"
                )

        let invalidFileReference =
            ClipboardFileReference(
                path:
                    context.testRoot
                        .appendingPathComponent(
                            "Invalid Document.txt"
                        )
                        .path,
                displayName:
                    "Invalid Document.txt",
                isDirectory:
                    false,
                byteCount:
                    128,
                bookmarkData:
                    nil
            )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        ClipboardItem(
                            text:
                                "Existing backup text"
                        ),
                        ClipboardItem(
                            payload:
                                .image(
                                    imagePayload
                                )
                        ),
                        ClipboardItem(
                            payload:
                                .files(
                                    ClipboardFilesPayload(
                                        files: [
                                            invalidFileReference
                                        ]
                                    )
                                )
                        )
                    ]
                )

        do {
            let contents =
                try context
                    .importService
                    .readPackage(
                        at:
                            packageURL
                    )

            _ =
                try await context
                    .importService
                    .restorePackage(
                        contents
                    )

            Issue.record(
                "Expected malformed File metadata to stop the import before restoration."
            )
        } catch let error
            as ClipboardBackupPackageImportError
        {
            #expect(
                error ==
                    .invalidFileReference
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

        let packagedImageURL =
            packageURL
                .appendingPathComponent(
                    ClipboardBackupPackageService
                        .imagesFolderName,
                    isDirectory:
                        true
                )
                .appendingPathComponent(
                    imagePayload
                        .storedFilename,
                    isDirectory:
                        false
                )

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        packagedImageURL.path
                )
        )
    }
    
    @Test
    func restoresOrdinaryFileReferenceWithoutEmbeddingFileContents()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let originalFileURL =
            context.testRoot
                .appendingPathComponent(
                    "Original Document.txt"
                )

        let originalBookmarkData =
            Data([
                10,
                20,
                30,
                40
            ])

        let originalReference =
            ClipboardFileReference(
                path:
                    originalFileURL.path,
                displayName:
                    "Original Document.txt",
                isDirectory:
                    false,
                byteCount:
                    128,
                bookmarkData:
                    originalBookmarkData
            )

        let originalItem =
            ClipboardItem(
                payload:
                    .files(
                        ClipboardFilesPayload(
                            files: [
                                originalReference
                            ]
                        )
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

        let packagedFilesDirectoryURL =
            packageURL
                .appendingPathComponent(
                    "Files",
                    isDirectory:
                        true
                )

        #expect(
            !FileManager.default
                .fileExists(
                    atPath:
                        packagedFilesDirectoryURL.path
                )
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

        let restoredFilesPayload =
            try #require(
                restoredItem.filesPayload
            )

        let restoredReference =
            try #require(
                restoredFilesPayload.files.first
            )

        #expect(
            restoredReference.path ==
                originalReference.path
        )

        #expect(
            restoredReference.displayName ==
                originalReference.displayName
        )

        #expect(
            restoredReference.isDirectory ==
                originalReference.isDirectory
        )

        #expect(
            restoredReference.byteCount ==
                originalReference.byteCount
        )

        #expect(
            restoredReference.bookmarkData ==
                originalBookmarkData
        )

        #expect(
            !restoredReference.isSymbolicLink
        )

        #expect(
            restoredItem.origin ==
                .restored
        )
    }
    
    @Test
    func restoresSymbolicLinkMetadataWithoutEmbeddingTargetContents()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let symbolicLinkIdentifier =
            UUID()

        let symbolicLinkPath =
            context.testRoot
                .appendingPathComponent(
                    "Photo Link"
                )
                .path

        let symbolicLinkDestination =
            "../Pictures/Family Photo.png"

        let originalReference =
            ClipboardFileReference(
                path:
                    symbolicLinkPath,
                displayName:
                    "Photo Link",
                isDirectory:
                    false,
                byteCount:
                    nil,
                bookmarkData:
                    nil,
                symbolicLinkIdentifier:
                    symbolicLinkIdentifier,
                symbolicLinkDestination:
                    symbolicLinkDestination
            )

        let originalItem =
            ClipboardItem(
                payload:
                    .files(
                        ClipboardFilesPayload(
                            files: [
                                originalReference
                            ]
                        )
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

        let packagedFilesDirectoryURL =
            packageURL
                .appendingPathComponent(
                    "Files",
                    isDirectory:
                        true
                )

        #expect(
            !FileManager.default
                .fileExists(
                    atPath:
                        packagedFilesDirectoryURL.path
                )
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

        let restoredFilesPayload =
            try #require(
                restoredItem.filesPayload
            )

        let restoredReference =
            try #require(
                restoredFilesPayload.files.first
            )

        #expect(
            restoredReference.path ==
                symbolicLinkPath
        )

        #expect(
            restoredReference.displayName ==
                "Photo Link"
        )

        #expect(
            restoredReference.symbolicLinkIdentifier ==
                symbolicLinkIdentifier
        )

        #expect(
            restoredReference.symbolicLinkDestination ==
                symbolicLinkDestination
        )

        #expect(
            restoredReference.bookmarkData ==
                nil
        )

        #expect(
            restoredReference.isSymbolicLink
        )

        #expect(
            restoredReference.kindDisplayName ==
                "Symbolic Link"
        )

        #expect(
            restoredItem.origin ==
                .restored
        )
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
    func restoredImageDiscardedAsMergeDuplicateIsDeleted()
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
                    10,
                height:
                    7
            )

        let originalPayload =
            try await context
                .imageStorageService
                .storeImage(
                    data:
                        imageData,
                    originalFilename:
                        "Duplicate.png"
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

        let existingDuplicateItem =
            ClipboardItem(
                payload:
                    .image(
                        ClipboardImagePayload(
                            storageIdentifier:
                                UUID(),
                            format:
                                restoredPayload.format,
                            pixelWidth:
                                restoredPayload.pixelWidth,
                            pixelHeight:
                                restoredPayload.pixelHeight,
                            byteCount:
                                restoredPayload.byteCount,
                            contentHash:
                                restoredPayload.contentHash,
                            originalFilename:
                                restoredPayload.originalFilename,
                            wasConverted:
                                restoredPayload.wasConverted,
                            originalFileReference:
                                restoredPayload
                                    .originalFileReference
                        )
                    )
            )

        let preparation =
            ClipboardImportService
                .prepareCompleteMerge(
                    existingItems: [
                        existingDuplicateItem
                    ],
                    backupItems:
                        restoration.items
                )

        #expect(
            preparation.duplicateCount ==
                1
        )

        #expect(
            preparation.preparedItems ==
                [
                    existingDuplicateItem
                ]
        )

        await context
            .importService
            .deleteUnretainedRestoredImageAssets(
                from:
                    restoration,
                retainedItems:
                    preparation.preparedItems
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
                "Expected the restored duplicate image asset to be deleted."
            )
        } catch {
            // Expected.
        }
    }
    
    @Test
    func restoredImageDiscardedByHistoryLimitIsDeleted()
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
                                12,
                            height:
                                8
                        ),
                    originalFilename:
                        "Older Restored Image.png"
                )

        let olderRestoredImageItem =
            ClipboardItem(
                payload:
                    .image(
                        originalPayload
                    ),
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            1_000
                    )
            )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        olderRestoredImageItem
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

        let newerExistingItem =
            ClipboardItem(
                text:
                    "Newer existing history item",
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            2_000
                    )
            )

        let preparation =
            ClipboardImportService
                .prepareCompleteMerge(
                    existingItems: [
                        newerExistingItem
                    ],
                    backupItems:
                        restoration.items
                )

        let resolution =
            ClipboardImportService
                .resolveHistoryLimit(
                    for:
                        preparation
                            .preparedItems,
                    currentHistoryLimit:
                        1,
                    maximumHistoryLimit:
                        ClipboardStore
                            .maximumHistoryLimit,
                    decision:
                        .keepLimit
                )

        #expect(
            resolution.resolvedItems ==
                [
                    newerExistingItem
                ]
        )

        #expect(
            resolution.skippedUnpinnedItemCount ==
                1
        )

        await context
            .importService
            .deleteUnretainedRestoredImageAssets(
                from:
                    restoration,
                retainedItems:
                    resolution
                        .resolvedItems
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
                "Expected the restored image removed by the history limit to be deleted."
            )
        } catch {
            // Expected.
        }
    }
    
    @Test
    func replacementDeletesPriorImageAndPreservesRestoredImage()
        async throws
    {
        let context =
            makeContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let priorImagePayload =
            try await context
                .restoredImageStorageService
                .storeImage(
                    data:
                        makePNGData(
                            width:
                                9,
                            height:
                                9
                        ),
                    originalFilename:
                        "Prior History Image.png"
                )

        let priorHistoryItem =
            ClipboardItem(
                payload:
                    .image(
                        priorImagePayload
                    ),
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            1_000
                    )
            )

        let backupImagePayload =
            try await context
                .imageStorageService
                .storeImage(
                    data:
                        makePNGData(
                            width:
                                13,
                            height:
                                8
                        ),
                    originalFilename:
                        "Restored Replacement Image.png"
                )

        let backupImageItem =
            ClipboardItem(
                payload:
                    .image(
                        backupImagePayload
                    ),
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            2_000
                    )
            )

        let packageURL =
            try await context
                .packageService
                .exportBackup(
                    items: [
                        backupImageItem
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

        let replacementPreparation =
            ClipboardImportService
                .prepareCompleteReplacement(
                    backupItems:
                        restoration.items
                )

        #expect(
            replacementPreparation
                .preparedItems ==
                [
                    restoredItem
                ]
        )

        let replacementResolution =
            ClipboardImportService
                .resolveHistoryLimit(
                    for:
                        replacementPreparation
                            .preparedItems,
                    currentHistoryLimit:
                        10,
                    maximumHistoryLimit:
                        ClipboardStore
                            .maximumHistoryLimit,
                    decision:
                        .keepLimit
                )

        #expect(
            replacementResolution
                .resolvedItems ==
                [
                    restoredItem
                ]
        )

        let priorImagePayloadsToDelete =
            ClipboardImageAssetCleanupService
                .unreferencedImagePayloads(
                    previousItems: [
                        priorHistoryItem
                    ],
                    remainingItems:
                        replacementResolution
                            .resolvedItems
                )

        #expect(
            priorImagePayloadsToDelete ==
                [
                    priorImagePayload
                ]
        )

        for imagePayload in
            priorImagePayloadsToDelete
        {
            try await context
                .restoredImageStorageService
                .deleteImage(
                    for:
                        imagePayload
                )
        }

        await context
            .importService
            .deleteUnretainedRestoredImageAssets(
                from:
                    restoration,
                retainedItems:
                    replacementResolution
                        .resolvedItems
            )

        do {
            _ =
                try await context
                    .restoredImageStorageService
                    .loadImageData(
                        for:
                            priorImagePayload
                    )

            Issue.record(
                "Expected the image asset from the prior history to be deleted."
            )
        } catch {
            // Expected.
        }

        _ =
            try await context
                .restoredImageStorageService
                .loadImageData(
                    for:
                        restoredPayload
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
