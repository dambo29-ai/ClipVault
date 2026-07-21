//
//  ClipboardFileVisualServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/20/26.
//

import AppKit
import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardFileVisualServiceTests {
    @Test
    func ordinaryFileUsesQuickLookThumbnailWhenAvailable()
        async throws
    {
        let testDirectory =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "ClipboardFileVisualServiceTests-" +
                        UUID().uuidString,
                    isDirectory:
                        true
                )

        defer {
            try? FileManager.default
                .removeItem(
                    at:
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
                    "Report.pdf"
                )

        try Data([
            1,
            2,
            3
        ])
        .write(
            to:
                fileURL
        )

        var thumbnailRequestCount =
            0

        var workspaceRequestCount =
            0

        let service =
            makeService(
                resolvedURL:
                    fileURL,
                thumbnailLoader: {
                    requestedURL,
                    _,
                    _ in

                    thumbnailRequestCount += 1

                    #expect(
                        requestedURL ==
                            fileURL
                                .standardizedFileURL
                    )

                    return makeImage()
                },
                workspaceIconLoader: {
                    _ in

                    workspaceRequestCount += 1

                    return makeImage()
                }
            )

        let visual =
            await service.visual(
                for:
                    makePayload(
                        path:
                            fileURL.path
                    ),
                size:
                    CGSize(
                        width:
                            168,
                        height:
                            126
                    ),
                scale:
                    2
            )

        #expect(
            visual.source ==
                .quickLookThumbnail
        )

        #expect(
            thumbnailRequestCount ==
                1
        )

        #expect(
            workspaceRequestCount ==
                0
        )
    }

    @Test
    func folderUsesWorkspaceIconWithoutThumbnailRequest()
        async
    {
        var thumbnailRequestCount =
            0

        var workspacePaths:
            [String] = []

        let service =
            makeService(
                resolvedURL:
                    URL(
                        fileURLWithPath:
                            "/Preview/Folder"
                    ),
                thumbnailLoader: {
                    _,
                    _,
                    _ in

                    thumbnailRequestCount += 1

                    return makeImage()
                },
                workspaceIconLoader: {
                    paths in

                    workspacePaths =
                        paths

                    return makeImage()
                }
            )

        let payload =
            ClipboardFilesPayload(
                files: [
                    ClipboardFileReference(
                        path:
                            "/Preview/Folder",
                        displayName:
                            "Folder",
                        isDirectory:
                            true,
                        bookmarkData:
                            Data([1])
                    )
                ]
            )

        let visual =
            await service.visual(
                for:
                    payload,
                size:
                    CGSize(
                        width:
                            168,
                        height:
                            126
                    ),
                scale:
                    2
            )

        #expect(
            visual.source ==
                .workspaceIcon
        )

        #expect(
            thumbnailRequestCount ==
                0
        )

        #expect(
            workspacePaths ==
                [
                    "/Preview/Folder"
                ]
        )
    }

    @Test
    func groupedFilesUseWorkspaceGroupIcon()
        async
    {
        var thumbnailRequestCount =
            0

        var workspacePaths:
            [String] = []

        let service =
            makeService(
                resolvedURL:
                    URL(
                        fileURLWithPath:
                            "/Preview/First.pdf"
                    ),
                thumbnailLoader: {
                    _,
                    _,
                    _ in

                    thumbnailRequestCount += 1

                    return makeImage()
                },
                workspaceIconLoader: {
                    paths in

                    workspacePaths =
                        paths

                    return makeImage()
                }
            )

        let payload =
            ClipboardFilesPayload(
                files: [
                    ClipboardFileReference(
                        path:
                            "/Preview/First.pdf",
                        displayName:
                            "First.pdf",
                        isDirectory:
                            false,
                        bookmarkData:
                            Data([1])
                    ),
                    ClipboardFileReference(
                        path:
                            "/Preview/Second.txt",
                        displayName:
                            "Second.txt",
                        isDirectory:
                            false,
                        bookmarkData:
                            Data([2])
                    )
                ]
            )

        let visual =
            await service.visual(
                for:
                    payload,
                size:
                    CGSize(
                        width:
                            168,
                        height:
                            126
                    ),
                scale:
                    2
            )

        #expect(
            visual.source ==
                .workspaceIcon
        )

        #expect(
            thumbnailRequestCount ==
                0
        )

        #expect(
            workspacePaths ==
                [
                    "/Preview/First.pdf",
                    "/Preview/Second.txt"
                ]
        )
    }

    private func makeService(
        resolvedURL:
            URL,
        thumbnailLoader:
            @escaping
            ClipboardFileVisualService
                .ThumbnailLoader,
        workspaceIconLoader:
            @escaping
            ClipboardFileVisualService
                .WorkspaceIconLoader
    ) -> ClipboardFileVisualService {
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
                            resolvedURL,
                        isStale:
                            false
                    )
                },
                securityScopedAccessStarter: {
                    _ in
                    false
                }
            )

        return ClipboardFileVisualService(
            fileReferenceService:
                referenceService,
            thumbnailLoader:
                thumbnailLoader,
            workspaceIconLoader:
                workspaceIconLoader
        )
    }

    private func makePayload(
        path:
            String
    ) -> ClipboardFilesPayload {
        ClipboardFilesPayload(
            files: [
                ClipboardFileReference(
                    path:
                        path,
                    displayName:
                        URL(
                            fileURLWithPath:
                                path
                        )
                        .lastPathComponent,
                    isDirectory:
                        false,
                    bookmarkData:
                        Data([1])
                )
            ]
        )
    }

    private func makeImage()
        -> NSImage
    {
        NSImage(
            size:
                NSSize(
                    width:
                        32,
                    height:
                        32
                )
        )
    }
}
