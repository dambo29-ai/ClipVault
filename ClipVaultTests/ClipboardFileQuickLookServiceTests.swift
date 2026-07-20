//
//  ClipboardFileQuickLookServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/20/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardFileQuickLookServiceTests {
    @Test
    func ordinaryFileReferenceCanPreparePreview()
        throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        try FileManager.default
            .createDirectory(
                at:
                    testDirectory,
                withIntermediateDirectories:
                    true
            )

        let fileURL =
            testDirectory
                .appendingPathComponent(
                    "Preview Document.txt"
                )

        try Data(
            "Preview contents"
                .utf8
        )
        .write(
            to:
                fileURL
        )

        var stopAccessCount =
            0

        let referenceService =
            ClipboardFileReferenceService(
                bookmarkCreator: {
                    _ in
                    Data([1])
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
                    stopAccessCount += 1
                }
            )

        let service =
            ClipboardFileQuickLookService(
                fileReferenceService:
                    referenceService
            )

        let payload =
            ClipboardFilesPayload(
                files: [
                    ClipboardFileReference(
                        path:
                            fileURL.path,
                        displayName:
                            fileURL
                                .lastPathComponent,
                        isDirectory:
                            false,
                        byteCount:
                            16,
                        bookmarkData:
                            Data([1])
                    )
                ]
            )

        let previewURLs =
            try service
                .preparePreview(
                    for:
                        payload
                )

        #expect(
            previewURLs ==
                [
                    fileURL
                        .standardizedFileURL
                ]
        )

        #expect(
            stopAccessCount ==
                0
        )

        service.dismissPreview()

        #expect(
            stopAccessCount ==
                1
        )
    }

    @Test
    func symbolicLinkCanPreparePreview()
        throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        try FileManager.default
            .createDirectory(
                at:
                    testDirectory,
                withIntermediateDirectories:
                    true
            )

        let targetURL =
            testDirectory
                .appendingPathComponent(
                    "Target.txt"
                )

        try Data(
            "Target contents"
                .utf8
        )
        .write(
            to:
                targetURL
        )

        let symbolicLinkStorageService =
            ClipboardSymbolicLinkStorageService(
                storageRootURL:
                    testDirectory
                        .appendingPathComponent(
                            "Symbolic Link Storage",
                            isDirectory:
                                true
                        )
            )

        let referenceService =
            ClipboardFileReferenceService(
                bookmarkCreator: {
                    _ in
                    Data([1])
                },
                bookmarkResolver: {
                    _ in

                    throw TestError
                        .unexpectedBookmarkResolution
                },
                symbolicLinkStorageService:
                    symbolicLinkStorageService
            )

        let service =
            ClipboardFileQuickLookService(
                fileReferenceService:
                    referenceService
            )

        let payload =
            ClipboardFilesPayload(
                files: [
                    ClipboardFileReference(
                        path:
                            testDirectory
                                .appendingPathComponent(
                                    "Photo Link"
                                )
                                .path,
                        displayName:
                            "Photo Link",
                        isDirectory:
                            false,
                        bookmarkData:
                            nil,
                        symbolicLinkIdentifier:
                            UUID(),
                        symbolicLinkDestination:
                            targetURL.path
                    )
                ]
            )

        let previewURLs =
            try service
                .preparePreview(
                    for:
                        payload
                )

        let previewURL =
            try #require(
                previewURLs.first
            )

        let attributes =
            try FileManager.default
                .attributesOfItem(
                    atPath:
                        previewURL.path
                )

        #expect(
            attributes[.type]
                as? FileAttributeType ==
                .typeSymbolicLink
        )

        let destination =
            try FileManager.default
                .destinationOfSymbolicLink(
                    atPath:
                        previewURL.path
                )

        #expect(
            destination ==
                targetURL.path
        )

        service.dismissPreview()
    }

    private func makeTestDirectory()
        -> URL
    {
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "ClipboardFileQuickLookServiceTests-" +
                    UUID().uuidString,
                isDirectory:
                    true
            )
    }

    private func removeTestDirectory(
        _ directoryURL:
            URL
    ) {
        try? FileManager.default
            .removeItem(
                at:
                    directoryURL
            )
    }
}

private enum TestError:
    Error
{
    case unexpectedBookmarkResolution
}
