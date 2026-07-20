//
//  ClipboardFileReferenceServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/17/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardFileReferenceServiceTests {
    @Test
    func createsReferenceForFile()
        throws
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

        let fileData =
            Data(
                "ClipVault file reference"
                    .utf8
            )

        try fileData.write(
            to:
                fileURL
        )

        let reference =
            try context.service
                .makeReference(
                    for:
                        fileURL
                )

        #expect(
            reference.path ==
                fileURL
                    .standardizedFileURL
                    .path
        )

        #expect(
            reference.displayName ==
                "Report.txt"
        )

        #expect(
            !reference.isDirectory
        )

        #expect(
            reference.byteCount ==
                fileData.count
        )

        #expect(
            reference.bookmarkData ==
                context.bookmarkData
        )
    }

    @Test
    func createsReferenceForFolderWithoutByteCount()
        throws
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

        let reference =
            try context.service
                .makeReference(
                    for:
                        folderURL
                )

        #expect(
            reference.displayName ==
                "Project"
        )

        #expect(
            reference.isDirectory
        )

        #expect(
            reference.byteCount == nil
        )
    }
    
    @Test
    func symbolicLinkIsCapturedWithoutBookmark()
        throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let targetURL =
            context.rootURL
                .appendingPathComponent(
                    "Target.png"
                )

        try Data([1, 2, 3])
            .write(
                to:
                    targetURL
            )

        let symbolicLinkURL =
            context.rootURL
                .appendingPathComponent(
                    "Photo Link"
                )

        try FileManager.default
            .createSymbolicLink(
                atPath:
                    symbolicLinkURL.path,
                withDestinationPath:
                    targetURL.path
            )

        let reference =
            try context.service
                .makeReference(
                    for:
                        symbolicLinkURL
                )

        #expect(
            reference.isSymbolicLink
        )

        #expect(
            reference.bookmarkData ==
                nil
        )

        #expect(
            reference.symbolicLinkDestination ==
                targetURL.path
        )

        #expect(
            reference.displayName ==
                "Photo Link"
        )

        #expect(
            reference.kindDisplayName ==
                "Symbolic Link"
        )
    }

    @Test
    func missingResourceIsRejected()
        throws
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

        do {
            _ =
                try context.service
                    .makeReference(
                        for:
                            missingURL
                    )

            Issue.record(
                "Expected a missing resource to be rejected."
            )
        } catch let error
            as ClipboardFileReferenceError
        {
            #expect(
                error ==
                    .resourceUnavailable
            )
        }
    }

    @Test
    func nonFileURLIsRejected()
        throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let webURL =
            try #require(
                URL(
                    string:
                        "https://example.com/file.txt"
                )
            )

        do {
            _ =
                try context.service
                    .makeReference(
                        for:
                            webURL
                    )

            Issue.record(
                "Expected a non-file URL to be rejected."
            )
        } catch let error
            as ClipboardFileReferenceError
        {
            #expect(
                error ==
                    .notFileURL
            )
        }
    }

    @Test
    func bookmarkCreationFailureIsMapped()
        throws
    {
        let context =
            try makeContext(
                bookmarkCreator: {
                    _ in

                    throw TestError
                        .bookmarkFailure
                }
            )

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let fileURL =
            context.rootURL
                .appendingPathComponent(
                    "Failure.txt"
                )

        try Data(
            "Failure"
                .utf8
        )
        .write(
            to:
                fileURL
        )

        do {
            _ =
                try context.service
                    .makeReference(
                        for:
                            fileURL
                    )

            Issue.record(
                "Expected bookmark creation to fail."
            )
        } catch let error
            as ClipboardFileReferenceError
        {
            #expect(
                error ==
                    .bookmarkUnavailable
            )
        }
    }

    @Test
    func batchCreationKeepsValidReferencesAndReportsFailures()
        throws
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

        let missingURL =
            context.rootURL
                .appendingPathComponent(
                    "Missing.txt"
                )

        let result =
            context.service
                .makeReferences(
                    for: [
                        validURL,
                        missingURL
                    ]
                )

        #expect(
            result.succeededCount ==
                1
        )

        #expect(
            result.failedCount ==
                1
        )

        #expect(
            result.references.first?
                .displayName ==
                "Valid.txt"
        )

        #expect(
            result.failedURLs ==
                [
                    missingURL
                ]
        )
    }

    @Test
    func resolvesBookmarkToExistingResource()
        throws
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
                    "Resolved.txt"
                )

        try Data(
            "Resolved"
                .utf8
        )
        .write(
            to:
                fileURL
        )

        let reference =
            ClipboardFileReference(
                path:
                    "/Original/Path/Resolved.txt",
                displayName:
                    "Resolved.txt",
                isDirectory:
                    false,
                byteCount:
                    8,
                bookmarkData:
                    context.bookmarkData
            )

        context.resolvedURLBox.url =
            fileURL

        let resolvedReference =
            try context.service
                .resolve(
                    reference
                )

        defer {
            resolvedReference
                .stopAccessing()
        }

        #expect(
            resolvedReference
                .url
                .standardizedFileURL
                .path ==
            fileURL
                .standardizedFileURL
                .path
        )
    }
    
    @Test
    func resolvedUnavailableResourceIsRejectedWithRetryableError()
        throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let unavailableURL =
            context.rootURL
                .appendingPathComponent(
                    "Disconnected Drive",
                    isDirectory:
                        true
                )
                .appendingPathComponent(
                    "Archived Report.pdf"
                )

        context.resolvedURLBox.url =
            unavailableURL

        let reference =
            ClipboardFileReference(
                path:
                    unavailableURL.path,
                displayName:
                    "Archived Report.pdf",
                isDirectory:
                    false,
                byteCount:
                    nil,
                bookmarkData:
                    context.bookmarkData
            )

        do {
            _ =
                try context.service
                    .resolve(
                        reference
                    )

            Issue.record(
                "Expected the unavailable resource to be rejected."
            )
        } catch let error
            as ClipboardFileReferenceError
        {
            #expect(
                error ==
                    .resourceUnavailable
            )

            #expect(
                error.localizedDescription
                    .localizedCaseInsensitiveContains(
                        "disconnected"
                    )
            )
        }
    }

    @Test
    func staleBookmarkIsRejected()
        throws
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

        let reference =
            ClipboardFileReference(
                path:
                    fileURL.path,
                displayName:
                    "Stale.txt",
                isDirectory:
                    false,
                bookmarkData:
                    context.bookmarkData
            )

        do {
            _ =
                try context.service
                    .resolve(
                        reference
                    )

            Issue.record(
                "Expected a stale bookmark to be rejected."
            )
        } catch let error
            as ClipboardFileReferenceError
        {
            #expect(
                error ==
                    .staleBookmark
            )
        }
    }

    @Test
    func invalidBookmarkIsRejected()
        throws
    {
        let context =
            try makeContext(
                bookmarkResolver: {
                    _ in

                    throw TestError
                        .bookmarkFailure
                }
            )

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let reference =
            ClipboardFileReference(
                path:
                    "/tmp/Invalid.txt",
                displayName:
                    "Invalid.txt",
                isDirectory:
                    false,
                bookmarkData:
                    context.bookmarkData
            )

        do {
            _ =
                try context.service
                    .resolve(
                        reference
                    )

            Issue.record(
                "Expected an invalid bookmark to be rejected."
            )
        } catch let error
            as ClipboardFileReferenceError
        {
            #expect(
                error ==
                    .invalidBookmark
            )
        }
    }

    @Test
    func referenceWithoutBookmarkIsRejected()
        throws
    {
        let context =
            try makeContext()

        defer {
            removeDirectory(
                context.rootURL
            )
        }

        let reference =
            ClipboardFileReference(
                path:
                    "/tmp/No Bookmark.txt",
                displayName:
                    "No Bookmark.txt",
                isDirectory:
                    false
            )

        do {
            _ =
                try context.service
                    .resolve(
                        reference
                    )

            Issue.record(
                "Expected a missing bookmark to be rejected."
            )
        } catch let error
            as ClipboardFileReferenceError
        {
            #expect(
                error ==
                    .invalidBookmark
            )
        }
    }

    private func makeContext(
        bookmarkCreator:
            ((URL) throws -> Data)? =
                nil,
        bookmarkResolver:
            ((Data) throws -> (
                url: URL,
                isStale: Bool
            ))? =
                nil,
        bookmarkIsStale: Bool =
            false
    ) throws -> TestContext {
        let rootURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "ClipboardFileReferenceServiceTests-" +
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

        let service =
            ClipboardFileReferenceService(
                bookmarkCreator:
                    bookmarkCreator ??
                    {
                        _ in

                        bookmarkData
                    },
                bookmarkResolver:
                    bookmarkResolver ??
                    {
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
            service:
                service
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

        let service:
            ClipboardFileReferenceService
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

    private enum TestError:
        Error
    {
        case bookmarkFailure
    }
}
