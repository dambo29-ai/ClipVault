//
//  ClipboardBackupPackageServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/17/26.
//

import AppKit
import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardBackupPackageServiceTests {
    @Test
    func exportCreatesBackupPackageStructure()
        async throws
    {
        let testRoot =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testRoot
            )
        }

        let exportsDirectory =
            testRoot
                .appendingPathComponent(
                    "Exports",
                    isDirectory: true
                )

        let imagesDirectory =
            testRoot
                .appendingPathComponent(
                    "Managed Images",
                    isDirectory: true
                )

        let imageStorageService =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    imagesDirectory
            )

        let service =
            ClipboardBackupPackageService(
                exportsDirectoryURL:
                    exportsDirectory,
                imageStorageService:
                    imageStorageService
            )

        let exportedAt =
            Date(
                timeIntervalSince1970:
                    1_800_000_000
            )

        let packageURL =
            try await service.exportBackup(
                items: [
                    ClipboardItem(
                        text:
                            "Backup text"
                    )
                ],
                exportedAt:
                    exportedAt
            )

        #expect(
            packageURL
                .pathExtension ==
                "clipvaultbackup"
        )

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        packageURL.path
                )
        )

        let manifestURL =
            packageURL
                .appendingPathComponent(
                    "manifest.json"
                )

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        manifestURL.path
                )
        )

        let imagesFolderURL =
            packageURL
                .appendingPathComponent(
                    "Images",
                    isDirectory: true
                )

        var isDirectory:
            ObjCBool = false

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        imagesFolderURL.path,
                    isDirectory:
                        &isDirectory
                )
        )

        #expect(
            isDirectory.boolValue
        )
    }

    @Test
    func manifestContainsVersionTwoAndNormalItems()
        async throws
    {
        let context =
            makeServiceContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let warningItem =
            ClipboardItem(
                text:
                    "Warning",
                kind:
                    .sensitiveSkipped
            )

        let packageURL =
            try await context.service
                .exportBackup(
                    items: [
                        ClipboardItem(
                            text:
                                "Normal item"
                        ),
                        warningItem
                    ],
                    exportedAt:
                        Date(
                            timeIntervalSince1970:
                                1_800_000_000
                        )
                )

        let manifest =
            try decodeManifest(
                from:
                    packageURL
            )

        #expect(
            manifest.appName ==
                "ClipVault"
        )

        #expect(
            manifest.formatVersion ==
                2
        )

        #expect(
            manifest.items.count ==
                1
        )

        #expect(
            manifest.items.first?
                .text ==
                "Normal item"
        )
    }

    @Test
    func imageAssetIsIncludedUsingStoredFilename()
        async throws
    {
        let context =
            makeServiceContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let imageData =
            try makePNGData(
                width: 8,
                height: 6
            )

        let imagePayload =
            try await context
                .imageStorageService
                .storeImage(
                    data:
                        imageData,
                    originalFilename:
                        "family-photo.png"
                )

        let imageItem =
            ClipboardItem(
                payload:
                    .image(
                        imagePayload
                    )
            )

        let packageURL =
            try await context.service
                .exportBackup(
                    items: [
                        imageItem
                    ]
                )

        let packagedImageURL =
            packageURL
                .appendingPathComponent(
                    "Images",
                    isDirectory: true
                )
                .appendingPathComponent(
                    imagePayload
                        .storedFilename
                )

        let packagedData =
            try Data(
                contentsOf:
                    packagedImageURL
            )

        #expect(
            packagedData ==
                imageData
        )
    }

    @Test
    func sharedImageAssetIsWrittenOnlyOnce()
        async throws
    {
        let context =
            makeServiceContext()

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
                            width: 5,
                            height: 5
                        )
                )

        let packageURL =
            try await context.service
                .exportBackup(
                    items: [
                        ClipboardItem(
                            id: UUID(),
                            payload:
                                .image(
                                    imagePayload
                                )
                        ),
                        ClipboardItem(
                            id: UUID(),
                            payload:
                                .image(
                                    imagePayload
                                )
                        )
                    ]
                )

        let imagesFolderURL =
            packageURL
                .appendingPathComponent(
                    "Images",
                    isDirectory: true
                )

        let imageURLs =
            try FileManager.default
                .contentsOfDirectory(
                    at:
                        imagesFolderURL,
                    includingPropertiesForKeys:
                        nil
                )

        #expect(
            imageURLs.count ==
                1
        )
    }

    @Test
    func missingManagedImageCausesExportToFail()
        async throws
    {
        let context =
            makeServiceContext()

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
                            width: 4,
                            height: 4
                        )
                )

        try await context
            .imageStorageService
            .deleteImage(
                for:
                    imagePayload
            )

        do {
            _ =
                try await context.service
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

            Issue.record(
                "Expected export to fail when a managed image is missing."
            )
        } catch {
            let exportsDirectoryExists =
                FileManager.default
                    .fileExists(
                        atPath:
                            context
                                .exportsDirectory
                                .path
                    )

            if exportsDirectoryExists {
                let remainingExportURLs =
                    try FileManager.default
                        .contentsOfDirectory(
                            at:
                                context
                                    .exportsDirectory,
                            includingPropertiesForKeys:
                                nil
                        )

                #expect(
                    remainingExportURLs.isEmpty
                )
            }
        }
    }

    @Test
    func exportingEmptyHistoryIsRejected()
        async throws
    {
        let context =
            makeServiceContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        do {
            _ =
                try await context.service
                    .exportBackup(
                        items: []
                    )

            Issue.record(
                "Expected empty history export to fail."
            )
        } catch let error
            as ClipboardBackupPackageError
        {
            #expect(
                error ==
                    .noHistory
            )
        }
    }
    
    @Test
    func latestBackupUsesManifestExportDate()
        async throws
    {
        let context =
            makeServiceContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let olderPackageURL =
            try await context.service
                .exportBackup(
                    items: [
                        ClipboardItem(
                            text:
                                "Older"
                        )
                    ],
                    exportedAt:
                        Date(
                            timeIntervalSince1970:
                                1_700_000_000
                        )
                )

        let newerPackageURL =
            try await context.service
                .exportBackup(
                    items: [
                        ClipboardItem(
                            text:
                                "Newer"
                        )
                    ],
                    exportedAt:
                        Date(
                            timeIntervalSince1970:
                                1_800_000_000
                        )
                )

        let latestBackupURL =
            try context.service
                .latestBackupURL()

        #expect(
            latestBackupURL
                .standardizedFileURL
                .path ==
            newerPackageURL
                .standardizedFileURL
                .path
        )

        #expect(
            latestBackupURL
                .standardizedFileURL
                .path !=
            olderPackageURL
                .standardizedFileURL
                .path
        )
    }
    
    @Test
    func malformedBackupPackageIsIgnored()
        async throws
    {
        let context =
            makeServiceContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let validPackageURL =
            try await context.service
                .exportBackup(
                    items: [
                        ClipboardItem(
                            text:
                                "Valid"
                        )
                    ]
                )

        let malformedPackageURL =
            context.exportsDirectory
                .appendingPathComponent(
                    "Malformed"
                )
                .appendingPathExtension(
                    "clipvaultbackup"
                )

        try FileManager.default
            .createDirectory(
                at:
                    malformedPackageURL,
                withIntermediateDirectories:
                    true
            )

        let latestBackupURL =
            try context.service
                .latestBackupURL()

        #expect(
            latestBackupURL
                .standardizedFileURL
                .path ==
            validPackageURL
                .standardizedFileURL
                .path
        )
    }
    
    @Test
    func deleteOldBackupsKeepsNewestPackages()
        async throws
    {
        let context =
            makeServiceContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        let oldestPackageURL =
            try await context.service
                .exportBackup(
                    items: [
                        ClipboardItem(
                            text:
                                "Oldest"
                        )
                    ],
                    exportedAt:
                        Date(
                            timeIntervalSince1970:
                                1_600_000_000
                        )
                )

        let middlePackageURL =
            try await context.service
                .exportBackup(
                    items: [
                        ClipboardItem(
                            text:
                                "Middle"
                        )
                    ],
                    exportedAt:
                        Date(
                            timeIntervalSince1970:
                                1_700_000_000
                        )
                )

        let newestPackageURL =
            try await context.service
                .exportBackup(
                    items: [
                        ClipboardItem(
                            text:
                                "Newest"
                        )
                    ],
                    exportedAt:
                        Date(
                            timeIntervalSince1970:
                                1_800_000_000
                        )
                )

        let result =
            try context.service
                .deleteOldBackups(
                    keepingMostRecent:
                        2
                )

        #expect(
            result.deletedCount ==
                1
        )

        #expect(
            result.keptCount ==
                2
        )

        #expect(
            !FileManager.default
                .fileExists(
                    atPath:
                        oldestPackageURL.path
                )
        )

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        middlePackageURL.path
                )
        )

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        newestPackageURL.path
                )
        )
    }
    
    @Test
    func latestBackupRejectsEmptyExportsFolder()
        throws
    {
        let context =
            makeServiceContext()

        defer {
            removeTestDirectory(
                context.testRoot
            )
        }

        do {
            _ =
                try context.service
                    .latestBackupURL()

            Issue.record(
                "Expected an empty exports folder to be rejected."
            )
        } catch let error
            as ClipboardBackupPackageError
        {
            #expect(
                error ==
                    .noBackupsFound
            )
        }
    }

    private func makeServiceContext()
        -> ServiceContext
    {
        let testRoot =
            makeTestDirectory()

        let exportsDirectory =
            testRoot
                .appendingPathComponent(
                    "Exports",
                    isDirectory: true
                )

        let imagesDirectory =
            testRoot
                .appendingPathComponent(
                    "Managed Images",
                    isDirectory: true
                )

        let imageStorageService =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    imagesDirectory
            )

        let service =
            ClipboardBackupPackageService(
                exportsDirectoryURL:
                    exportsDirectory,
                imageStorageService:
                    imageStorageService
            )

        return ServiceContext(
            testRoot:
                testRoot,
            exportsDirectory:
                exportsDirectory,
            imageStorageService:
                imageStorageService,
            service:
                service
        )
    }

    private func decodeManifest(
        from packageURL: URL
    ) throws
        -> ClipboardBackupPackageManifest
    {
        let manifestURL =
            packageURL
                .appendingPathComponent(
                    "manifest.json"
                )

        let data =
            try Data(
                contentsOf:
                    manifestURL
            )

        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601

        return try decoder.decode(
            ClipboardBackupPackageManifest
                .self,
            from:
                data
        )
    }

    private func makeTestDirectory()
        -> URL
    {
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "ClipboardBackupPackageServiceTests-" +
                UUID().uuidString,
                isDirectory: true
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

    private struct ServiceContext {
        let testRoot: URL
        let exportsDirectory: URL

        let imageStorageService:
            ClipboardImageStorageService

        let service:
            ClipboardBackupPackageService
    }

    private enum TestImageError:
        Error
    {
        case couldNotCreatePNG
    }
}
