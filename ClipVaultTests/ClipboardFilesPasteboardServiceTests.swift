//
//  ClipboardFilesPasteboardServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/17/26.
//

import AppKit
import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardFilesPasteboardServiceTests {
    @Test
    func resolvedFileWritesFileURLToPasteboard()
    async throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let fileURL =
            context.rootURL
                .appendingPathComponent(
                    "Report.txt"
                )

        try Data(
            "Report"
                .utf8
        )
        .write(
            to:
                fileURL
        )

        context.resolvedURLBox.url =
            fileURL

        let payload =
            makePayload(
                references: [
                    makeReference(
                        path:
                            "/Original/Report.txt",
                        displayName:
                            "Report.txt",
                        bookmarkData:
                            context.bookmarkData
                    )
                ]
            )

        let pasteboard =
            makePasteboard()

        let didWrite =
            try await context
                .pasteboardService
                .writeFiles(
                    payload,
                    to:
                        pasteboard
                )

        #expect(didWrite)

        let writtenURLs =
            pasteboard.readObjects(
                forClasses: [
                    NSURL.self
                ],
                options: [
                    .urlReadingFileURLsOnly:
                        true
                ]
            ) as? [NSURL]

        #expect(
            writtenURLs?
                .map {
                    ($0 as URL)
                        .standardizedFileURL
                        .path
                } ==
            [
                fileURL
                    .standardizedFileURL
                    .path
            ]
        )
    }

    @Test
    func resolvedFolderWritesFolderURLToPasteboard()
    async throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let folderURL =
            context.rootURL
                .appendingPathComponent(
                    "Project",
                    isDirectory:
                        true
                )

        try FileManager.default
            .createDirectory(
                at:
                    folderURL,
                withIntermediateDirectories:
                    true
            )

        context.resolvedURLBox.url =
            folderURL

        let payload =
            makePayload(
                references: [
                    makeReference(
                        path:
                            "/Original/Project",
                        displayName:
                            "Project",
                        isDirectory:
                            true,
                        bookmarkData:
                            context.bookmarkData
                    )
                ]
            )

        let pasteboard =
            makePasteboard()

        let didWrite =
            try await context
                .pasteboardService
                .writeFiles(
                    payload,
                    to:
                        pasteboard
                )

        #expect(didWrite)

        let writtenURLs =
            pasteboard.readObjects(
                forClasses: [
                    NSURL.self
                ],
                options: [
                    .urlReadingFileURLsOnly:
                        true
                ]
            ) as? [NSURL]

        #expect(
            writtenURLs?
                .first
                .map {
                    ($0 as URL)
                        .standardizedFileURL
                        .path
                } ==
            folderURL
                .standardizedFileURL
                .path
        )
    }

    @Test
    func multipleResolvedFilesAreWrittenTogether()
    async throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let firstURL =
            context.rootURL
                .appendingPathComponent(
                    "First.txt"
                )

        let secondURL =
            context.rootURL
                .appendingPathComponent(
                    "Second.txt"
                )

        try Data(
            "First"
                .utf8
        )
        .write(
            to:
                firstURL
        )

        try Data(
            "Second"
                .utf8
        )
        .write(
            to:
                secondURL
        )

        let resolvedURLs = [
            firstURL,
            secondURL
        ]

        let resolverIndexBox =
            ResolverIndexBox()

        let fileReferenceService =
            ClipboardFileReferenceService(
                bookmarkCreator: {
                    _ in
                    context.bookmarkData
                },
                bookmarkResolver: {
                    _ in

                    let index =
                        resolverIndexBox.index

                    resolverIndexBox.index += 1

                    return (
                        url:
                            resolvedURLs[index],
                        isStale:
                            false
                    )
                }
            )

        let service =
            ClipboardFilesPasteboardService(
                fileReferenceService:
                    fileReferenceService
            )

        let payload =
            makePayload(
                references: [
                    makeReference(
                        path:
                            "/Original/First.txt",
                        displayName:
                            "First.txt",
                        bookmarkData:
                            Data([1])
                    ),
                    makeReference(
                        path:
                            "/Original/Second.txt",
                        displayName:
                            "Second.txt",
                        bookmarkData:
                            Data([2])
                    )
                ]
            )

        let pasteboard =
            makePasteboard()

        let didWrite =
            try await service.writeFiles(
                payload,
                to:
                    pasteboard
            )

        #expect(didWrite)

        let writtenURLs =
            pasteboard.readObjects(
                forClasses: [
                    NSURL.self
                ],
                options: [
                    .urlReadingFileURLsOnly:
                        true
                ]
            ) as? [NSURL]

        #expect(
            writtenURLs?
                .map {
                    ($0 as URL)
                        .standardizedFileURL
                        .path
                } ==
            resolvedURLs.map {
                $0.standardizedFileURL.path
            }
        )
    }

    @Test
    func missingBookmarkDoesNotClearExistingClipboard()
    async throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let payload =
            makePayload(
                references: [
                    makeReference(
                        path:
                            "/Missing Bookmark.txt",
                        displayName:
                            "Missing Bookmark.txt",
                        bookmarkData:
                            nil
                    )
                ]
            )

        let pasteboard =
            makePasteboard()

        pasteboard.clearContents()

        pasteboard.setString(
            "Existing clipboard value",
            forType:
                .string
        )

        do {
            _ =
                try await context
                    .pasteboardService
                    .writeFiles(
                        payload,
                        to:
                            pasteboard
                    )

            Issue.record(
                "Expected a missing bookmark to fail."
            )
        } catch let error
            as ClipboardFileReferenceError
        {
            #expect(
                error ==
                    .invalidBookmark
            )
        }

        #expect(
            pasteboard.string(
                forType:
                    .string
            ) ==
            "Existing clipboard value"
        )
    }

    @Test
    func staleBookmarkDoesNotClearExistingClipboard()
    async throws
    {
        let context =
            try makeContext(
                bookmarkIsStale:
                    true
            )

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let fileURL =
            context.rootURL
                .appendingPathComponent(
                    "Stale.txt"
                )

        try Data(
            "Stale"
                .utf8
        )
        .write(
            to:
                fileURL
        )

        context.resolvedURLBox.url =
            fileURL

        let payload =
            makePayload(
                references: [
                    makeReference(
                        path:
                            fileURL.path,
                        displayName:
                            "Stale.txt",
                        bookmarkData:
                            context.bookmarkData
                    )
                ]
            )

        let pasteboard =
            makePasteboard()

        pasteboard.clearContents()

        pasteboard.setString(
            "Existing clipboard value",
            forType:
                .string
        )

        do {
            _ =
                try await context
                    .pasteboardService
                    .writeFiles(
                        payload,
                        to:
                            pasteboard
                    )

            Issue.record(
                "Expected a stale bookmark to fail."
            )
        } catch let error
            as ClipboardFileReferenceError
        {
            #expect(
                error ==
                    .staleBookmark
            )
        }

        #expect(
            pasteboard.string(
                forType:
                    .string
            ) ==
            "Existing clipboard value"
        )
    }

    @Test
    func missingResolvedFileDoesNotClearExistingClipboard()
    async throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let missingURL =
            context.rootURL
                .appendingPathComponent(
                    "Missing.txt"
                )

        context.resolvedURLBox.url =
            missingURL

        let payload =
            makePayload(
                references: [
                    makeReference(
                        path:
                            missingURL.path,
                        displayName:
                            "Missing.txt",
                        bookmarkData:
                            context.bookmarkData
                    )
                ]
            )

        let pasteboard =
            makePasteboard()

        pasteboard.clearContents()

        pasteboard.setString(
            "Existing clipboard value",
            forType:
                .string
        )

        do {
            _ =
                try await context
                    .pasteboardService
                    .writeFiles(
                        payload,
                        to:
                            pasteboard
                    )

            Issue.record(
                "Expected a missing resolved file to fail."
            )
        } catch let error
            as ClipboardFileReferenceError
        {
            #expect(
                error ==
                    .resourceUnavailable
            )
        }

        #expect(
            pasteboard.string(
                forType:
                    .string
            ) ==
            "Existing clipboard value"
        )
    }
    
    @Test
    func customTitleWritesRenamedStagedFileWithoutChangingOriginal()
        async throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let originalURL =
            context.rootURL
                .appendingPathComponent(
                    "Original Report.txt"
                )

        let originalData =
            Data(
                "Important report"
                    .utf8
            )

        try originalData.write(
            to:
                originalURL
        )

        context.resolvedURLBox.url =
            originalURL

        let stagingURL =
            context.rootURL
                .appendingPathComponent(
                    "Staging",
                    isDirectory:
                        true
                )

        let pasteboardService =
            ClipboardFilesPasteboardService(
                fileReferenceService:
                    context
                        .fileReferenceService,
                exportStagingService:
                    ClipboardFileExportStagingService(
                        stagingRootURL:
                            stagingURL
                    )
            )

        let payload =
            makePayload(
                references: [
                    makeReference(
                        path:
                            "/Original/Original Report.txt",
                        displayName:
                            "Original Report.txt",
                        bookmarkData:
                            context.bookmarkData
                    )
                ]
            )

        let pasteboard =
            makePasteboard()

        let didWrite =
            try await pasteboardService
                .writeFiles(
                    payload,
                    customTitle:
                        "Final Report",
                    exportIdentifier:
                        UUID(
                            uuidString:
                                "00000000-0000-0000-0000-000000000001"
                        )!,
                    to:
                        pasteboard
                )

        #expect(didWrite)

        let writtenURL =
            (
                pasteboard.readObjects(
                    forClasses: [
                        NSURL.self
                    ],
                    options: [
                        .urlReadingFileURLsOnly:
                            true
                    ]
                ) as? [NSURL]
            )?
            .first
            .map {
                $0 as URL
            }

        #expect(
            writtenURL?
                .lastPathComponent ==
            "Final Report.txt"
        )

        #expect(
            writtenURL?
                .standardizedFileURL !=
            originalURL
                .standardizedFileURL
        )

        #expect(
            writtenURL.flatMap {
                try? Data(
                    contentsOf:
                        $0
                )
            } ==
            originalData
        )

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        originalURL.path
                )
        )

        #expect(
            originalURL
                .lastPathComponent ==
            "Original Report.txt"
        )
    }
    
    @Test
    func customTitleWritesRenamedFolderWithCompleteContents()
        async throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let originalFolderURL =
            context.rootURL
                .appendingPathComponent(
                    "Original Project",
                    isDirectory:
                        true
                )

        try FileManager.default
            .createDirectory(
                at:
                    originalFolderURL,
                withIntermediateDirectories:
                    true
            )

        let nestedFileURL =
            originalFolderURL
                .appendingPathComponent(
                    "Notes.txt"
                )

        try Data(
            "Project notes"
                .utf8
        )
        .write(
            to:
                nestedFileURL
        )

        context.resolvedURLBox.url =
            originalFolderURL

        let stagingURL =
            context.rootURL
                .appendingPathComponent(
                    "Staging",
                    isDirectory:
                        true
                )

        let pasteboardService =
            ClipboardFilesPasteboardService(
                fileReferenceService:
                    context
                        .fileReferenceService,
                exportStagingService:
                    ClipboardFileExportStagingService(
                        stagingRootURL:
                            stagingURL
                    )
            )

        let payload =
            makePayload(
                references: [
                    makeReference(
                        path:
                            "/Original/Original Project",
                        displayName:
                            "Original Project",
                        isDirectory:
                            true,
                        bookmarkData:
                            context.bookmarkData
                    )
                ]
            )

        let pasteboard =
            makePasteboard()

        let didWrite =
            try await pasteboardService
                .writeFiles(
                    payload,
                    customTitle:
                        "Client Project",
                    exportIdentifier:
                        UUID(
                            uuidString:
                                "00000000-0000-0000-0000-000000000002"
                        )!,
                    to:
                        pasteboard
                )

        #expect(didWrite)

        let writtenURL =
            (
                pasteboard.readObjects(
                    forClasses: [
                        NSURL.self
                    ],
                    options: [
                        .urlReadingFileURLsOnly:
                            true
                    ]
                ) as? [NSURL]
            )?
            .first
            .map {
                $0 as URL
            }

        #expect(
            writtenURL?
                .lastPathComponent ==
            "Client Project"
        )

        #expect(
            writtenURL.map {
                FileManager.default
                    .fileExists(
                        atPath:
                            $0
                                .appendingPathComponent(
                                    "Notes.txt"
                                )
                                .path
                    )
            } ==
            true
        )

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        originalFolderURL.path
                )
        )

        #expect(
            originalFolderURL
                .lastPathComponent ==
            "Original Project"
        )
    }
    
    @Test
    func multipleFileEntriesPreserveOrderAndRenameOnlySelectedMember()
        async throws
    {
        let rootURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "ClipboardFilesGroupTest-" +
                    UUID().uuidString,
                    isDirectory:
                        true
                )

        defer {
            removeDirectory(
                rootURL
            )
        }

        try FileManager.default
            .createDirectory(
                at:
                    rootURL,
                withIntermediateDirectories:
                    true
            )

        let firstURL =
            rootURL
                .appendingPathComponent(
                    "First.txt"
                )

        let secondURL =
            rootURL
                .appendingPathComponent(
                    "Second.txt"
                )

        let thirdFolderURL =
            rootURL
                .appendingPathComponent(
                    "Third Folder",
                    isDirectory:
                        true
                )

        try Data(
            "First"
                .utf8
        )
        .write(
            to:
                firstURL
        )

        try Data(
            "Second"
                .utf8
        )
        .write(
            to:
                secondURL
        )

        try FileManager.default
            .createDirectory(
                at:
                    thirdFolderURL,
                withIntermediateDirectories:
                    true
            )

        let resolvedURLs =
            [
                firstURL,
                secondURL,
                thirdFolderURL
            ]

        let resolverIndexBox =
            ResolverIndexBox()

        let bookmarkData =
            Data([1, 2, 3])

        let referenceService =
            ClipboardFileReferenceService(
                bookmarkCreator: {
                    _ in
                    bookmarkData
                },
                bookmarkResolver: {
                    _ in

                    let index =
                        resolverIndexBox.index

                    resolverIndexBox.index += 1

                    return (
                        url:
                            resolvedURLs[index],
                        isStale:
                            false
                    )
                }
            )

        let stagingURL =
            rootURL
                .appendingPathComponent(
                    "Staging",
                    isDirectory:
                        true
                )

        let service =
            ClipboardFilesPasteboardService(
                fileReferenceService:
                    referenceService,
                exportStagingService:
                    ClipboardFileExportStagingService(
                        stagingRootURL:
                            stagingURL
                    )
            )

        let entries =
            [
                ClipboardFilesPasteboardEntry(
                    payload:
                        makePayload(
                            references: [
                                makeReference(
                                    path:
                                        "/Original/First.txt",
                                    displayName:
                                        "First.txt",
                                    bookmarkData:
                                        bookmarkData
                                )
                            ]
                        ),
                    customTitle:
                        nil,
                    exportIdentifier:
                        UUID()
                ),
                ClipboardFilesPasteboardEntry(
                    payload:
                        makePayload(
                            references: [
                                makeReference(
                                    path:
                                        "/Original/Second.txt",
                                    displayName:
                                        "Second.txt",
                                    bookmarkData:
                                        bookmarkData
                                )
                            ]
                        ),
                    customTitle:
                        "Renamed Second",
                    exportIdentifier:
                        UUID()
                ),
                ClipboardFilesPasteboardEntry(
                    payload:
                        makePayload(
                            references: [
                                makeReference(
                                    path:
                                        "/Original/Third Folder",
                                    displayName:
                                        "Third Folder",
                                    isDirectory:
                                        true,
                                    bookmarkData:
                                        bookmarkData
                                )
                            ]
                        ),
                    customTitle:
                        nil,
                    exportIdentifier:
                        UUID()
                )
            ]

        let pasteboard =
            makePasteboard()

        let didWrite =
            try await service
                .writeFileEntries(
                    entries,
                    to:
                        pasteboard
                )

        #expect(didWrite)

        let writtenNames =
            (
                pasteboard.readObjects(
                    forClasses: [
                        NSURL.self
                    ],
                    options: [
                        .urlReadingFileURLsOnly:
                            true
                    ]
                ) as? [NSURL]
            )?
            .map {
                ($0 as URL)
                    .lastPathComponent
            }

        #expect(
            writtenNames ==
                [
                    "First.txt",
                    "Renamed Second.txt",
                    "Third Folder"
                ]
        )

        #expect(
            firstURL.lastPathComponent ==
                "First.txt"
        )

        #expect(
            secondURL.lastPathComponent ==
                "Second.txt"
        )

        #expect(
            thirdFolderURL
                .lastPathComponent ==
                "Third Folder"
        )
    }

    @Test
    func partialResolutionFailureDoesNotClearClipboard()
    async throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let validURL =
            context.rootURL
                .appendingPathComponent(
                    "Valid.txt"
                )

        try Data(
            "Valid"
                .utf8
        )
        .write(
            to:
                validURL
        )

        let resolverCallBox =
            ResolverIndexBox()

        let service =
            ClipboardFilesPasteboardService(
                fileReferenceService:
                    ClipboardFileReferenceService(
                        bookmarkCreator: {
                            _ in
                            context.bookmarkData
                        },
                        bookmarkResolver: {
                            _ in

                            defer {
                                resolverCallBox.index += 1
                            }

                            if resolverCallBox.index == 0 {
                                return (
                                    url:
                                        validURL,
                                    isStale:
                                        false
                                )
                            }

                            throw TestError
                                .resolutionFailed
                        }
                    )
            )

        let payload =
            makePayload(
                references: [
                    makeReference(
                        path:
                            "/Original/Valid.txt",
                        displayName:
                            "Valid.txt",
                        bookmarkData:
                            Data([1])
                    ),
                    makeReference(
                        path:
                            "/Original/Invalid.txt",
                        displayName:
                            "Invalid.txt",
                        bookmarkData:
                            Data([2])
                    )
                ]
            )

        let pasteboard =
            makePasteboard()

        pasteboard.clearContents()

        pasteboard.setString(
            "Existing clipboard value",
            forType:
                .string
        )

        do {
            _ =
                try await service.writeFiles(
                    payload,
                    to:
                        pasteboard
                )

            Issue.record(
                "Expected partial resolution failure."
            )
        } catch let error
            as ClipboardFileReferenceError
        {
            #expect(
                error ==
                    .invalidBookmark
            )
        }

        #expect(
            pasteboard.string(
                forType:
                    .string
            ) ==
            "Existing clipboard value"
        )
    }

    @Test
    func emptyPayloadDoesNotClearClipboard()
    async throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let pasteboard =
            makePasteboard()

        pasteboard.clearContents()

        pasteboard.setString(
            "Existing clipboard value",
            forType:
                .string
        )

        let didWrite =
            try await context
                .pasteboardService
                .writeFiles(
                    ClipboardFilesPayload(
                        files: []
                    ),
                    to:
                        pasteboard
                )

        #expect(!didWrite)

        #expect(
            pasteboard.string(
                forType:
                    .string
            ) ==
            "Existing clipboard value"
        )
    }

    private func makeContext(
        bookmarkIsStale:
            Bool = false
    ) throws -> TestContext {
        let rootURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "ClipboardFilesPasteboardServiceTests-" +
                    UUID().uuidString,
                    isDirectory:
                        true
                )

        try FileManager.default
            .createDirectory(
                at:
                    rootURL,
                withIntermediateDirectories:
                    true
            )

        let bookmarkData =
            Data(
                [10, 20, 30, 40]
            )

        let resolvedURLBox =
            ResolvedURLBox(
                url:
                    rootURL
            )

        let fileReferenceService =
            ClipboardFileReferenceService(
                bookmarkCreator: {
                    _ in
                    bookmarkData
                },
                bookmarkResolver: {
                    _ in
                    (
                        url:
                            resolvedURLBox.url,
                        isStale:
                            bookmarkIsStale
                    )
                }
            )

        return TestContext(
            rootURL:
                rootURL,
            bookmarkData:
                bookmarkData,
            resolvedURLBox:
                resolvedURLBox,
            fileReferenceService:
                fileReferenceService,
            pasteboardService:
                ClipboardFilesPasteboardService(
                    fileReferenceService:
                        fileReferenceService
                )
        )
    }

    private func makePayload(
        references:
            [ClipboardFileReference]
    ) -> ClipboardFilesPayload {
        ClipboardFilesPayload(
            files:
                references
        )
    }

    private func makeReference(
        path: String,
        displayName: String,
        isDirectory:
            Bool = false,
        bookmarkData:
            Data?
    ) -> ClipboardFileReference {
        ClipboardFileReference(
            path:
                path,
            displayName:
                displayName,
            isDirectory:
                isDirectory,
            bookmarkData:
                bookmarkData
        )
    }

    private func makePasteboard()
        -> NSPasteboard
    {
        NSPasteboard(
            name:
                NSPasteboard.Name(
                    "ClipboardFilesPasteboardServiceTests-" +
                    UUID().uuidString
                )
        )
    }

    private func removeDirectory(
        _ directoryURL: URL
    ) {
        try? FileManager.default
            .removeItem(
                at:
                    directoryURL
            )
    }

    private struct TestContext {
        let rootURL: URL
        let bookmarkData: Data
        let resolvedURLBox:
            ResolvedURLBox

        let fileReferenceService:
            ClipboardFileReferenceService

        let pasteboardService:
            ClipboardFilesPasteboardService
    }

    private final class ResolvedURLBox {
        var url: URL

        init(
            url: URL
        ) {
            self.url =
                url
        }
    }

    private final class ResolverIndexBox {
        var index =
            0
    }

    private enum TestError:
        Error
    {
        case resolutionFailed
    }
}
