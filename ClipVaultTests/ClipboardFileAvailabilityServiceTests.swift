//
//  ClipboardFileAvailabilityServiceTests.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/19/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardFileAvailabilityServiceTests {
    @Test
    func existingFileIsAvailable()
        throws
    {
        let context =
            try makeContext(
                resourceExists:
                    true
            )

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let status =
            context.service.status(
                for:
                    context.payload
            )

        #expect(
            status ==
                .available
        )

        #expect(
            context.stopAccessCount
                .value ==
                1
        )
    }

    @Test
    func unavailableFileIsReportedUnavailable()
        throws
    {
        let context =
            try makeContext(
                resourceExists:
                    false
            )

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let status =
            context.service.status(
                for:
                    context.payload
            )

        #expect(
            status ==
                .unavailable
        )
    }

    @Test
    func oneUnavailableMemberMakesGroupUnavailable()
        throws
    {
        let rootURL =
            makeRootDirectory()

        defer {
            removeDirectory(
                rootURL
            )
        }

        let existingURL =
            rootURL
                .appendingPathComponent(
                    "Existing.txt"
                )

        try Data(
            "Existing"
                .utf8
        )
        .write(
            to:
                existingURL
        )

        let missingURL =
            rootURL
                .appendingPathComponent(
                    "Missing.txt"
                )

        let resolverIndex =
            IndexBox()

        let referenceService =
            ClipboardFileReferenceService(
                bookmarkCreator: {
                    _ in
                    Data([1])
                },
                bookmarkResolver: {
                    _ in

                    let urls =
                        [
                            existingURL,
                            missingURL
                        ]

                    let url =
                        urls[
                            resolverIndex.value
                        ]

                    resolverIndex.value += 1

                    return (
                        url:
                            url,
                        isStale:
                            false
                    )
                }
            )

        let service =
            ClipboardFileAvailabilityService(
                fileReferenceService:
                    referenceService
            )

        let payload =
            ClipboardFilesPayload(
                files: [
                    makeReference(
                        path:
                            existingURL.path,
                        displayName:
                            "Existing.txt"
                    ),
                    makeReference(
                        path:
                            missingURL.path,
                        displayName:
                            "Missing.txt"
                    )
                ]
            )

        #expect(
            service.status(
                for:
                    payload
            ) ==
            .unavailable
        )
    }
    
    @Test
    func cloudOnlyItemStartsDownloadingAndReportsDownloading()
        throws
    {
        let context =
            try makeContext(
                resourceExists:
                    true
            )

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let downloadCount =
            CountBox()

        let service =
            ClipboardFileAvailabilityService(
                fileReferenceService:
                    context
                        .referenceService,
                isUbiquitousItem: {
                    _ in
                    true
                },
                downloadingStatus: {
                    _ in
                    .notDownloaded
                },
                startDownloading: {
                    _ in

                    downloadCount.value += 1
                }
            )

        let status =
            service.status(
                for:
                    context.payload
            )

        #expect(
            status ==
                .downloading
        )

        #expect(
            downloadCount.value ==
                1
        )
    }
    
    @Test
    func downloadingCloudItemReportsDownloadingWithoutRestarting()
        throws
    {
        let context =
            try makeContext(
                resourceExists:
                    true
            )

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let downloadCount =
            CountBox()

        let service =
            ClipboardFileAvailabilityService(
                fileReferenceService:
                    context
                        .referenceService,
                isUbiquitousItem: {
                    _ in
                    true
                },
                downloadingStatus: {
                    _ in
                    .downloaded
                },
                startDownloading: {
                    _ in

                    downloadCount.value += 1
                }
            )

        let status =
            service.status(
                for:
                    context.payload
            )

        #expect(
            status ==
                .available
        )

        #expect(
            downloadCount.value ==
                0
        )
    }
    
    @Test
    func currentCloudItemIsAvailable()
        throws
    {
        let context =
            try makeContext(
                resourceExists:
                    true
            )

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let service =
            ClipboardFileAvailabilityService(
                fileReferenceService:
                    context
                        .referenceService,
                isUbiquitousItem: {
                    _ in
                    true
                },
                downloadingStatus: {
                    _ in
                    .current
                },
                startDownloading: {
                    _ in
                    Issue.record(
                        "A current iCloud item should not restart downloading."
                    )
                }
            )

        #expect(
            service.status(
                for:
                    context.payload
            ) ==
            .available
        )
    }

    @Test
    func emptyPayloadIsUnavailable()
    {
        let referenceService =
            ClipboardFileReferenceService(
                bookmarkCreator: {
                    _ in
                    Data()
                },
                bookmarkResolver: {
                    _ in
                    throw TestError
                        .unexpectedResolution
                }
            )

        let service =
            ClipboardFileAvailabilityService(
                fileReferenceService:
                    referenceService
            )

        #expect(
            service.status(
                for:
                    ClipboardFilesPayload(
                        files: []
                    )
            ) ==
            .unavailable
        )
    }

    private func makeContext(
        resourceExists:
            Bool
    ) throws -> TestContext {
        let rootURL =
            makeRootDirectory()

        let fileURL =
            rootURL
                .appendingPathComponent(
                    "Report.txt"
                )

        if resourceExists {
            try Data(
                "Report"
                    .utf8
            )
            .write(
                to:
                    fileURL
            )
        }

        let stopAccessCount =
            CountBox()

        let referenceService =
            ClipboardFileReferenceService(
                bookmarkCreator: {
                    _ in
                    Data([1, 2, 3])
                },
                bookmarkResolver: {
                    _ in

                    (
                        url:
                            fileURL,
                        isStale:
                            false
                    )
                },
                securityScopedAccessStarter: {
                    _ in
                    true
                },
                securityScopedAccessStopper: {
                    _ in

                    stopAccessCount
                        .value += 1
                }
            )

        let service =
            ClipboardFileAvailabilityService(
                fileReferenceService:
                    referenceService
            )

        let payload =
            ClipboardFilesPayload(
                files: [
                    makeReference(
                        path:
                            fileURL.path,
                        displayName:
                            "Report.txt"
                    )
                ]
            )

        return TestContext(
            rootURL:
                rootURL,
            payload:
                payload,
            referenceService:
                referenceService,
            service:
                service,
            stopAccessCount:
                stopAccessCount
        )
    }

    private func makeRootDirectory()
        -> URL
    {
        let rootURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "ClipboardAvailabilityTest-" +
                    UUID().uuidString,
                    isDirectory:
                        true
                )

        try? FileManager.default
            .createDirectory(
                at:
                    rootURL,
                withIntermediateDirectories:
                    true
            )

        return rootURL
    }

    private func makeReference(
        path:
            String,
        displayName:
            String
    ) -> ClipboardFileReference {
        ClipboardFileReference(
            path:
                path,
            displayName:
                displayName,
            isDirectory:
                false,
            byteCount:
                nil,
            bookmarkData:
                Data([1, 2, 3])
        )
    }

    private func removeDirectory(
        _ url:
            URL
    ) {
        try? FileManager.default
            .removeItem(
                at:
                    url
            )
    }

    private struct TestContext {
        let rootURL:
            URL

        let payload:
            ClipboardFilesPayload

        let referenceService:
            ClipboardFileReferenceService

        let service:
            ClipboardFileAvailabilityService

        let stopAccessCount:
            CountBox
    }

    private final class CountBox {
        var value = 0
    }

    private final class IndexBox {
        var value = 0
    }

    private enum TestError:
        Error
    {
        case unexpectedResolution
    }
}
