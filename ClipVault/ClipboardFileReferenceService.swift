//
//  ClipboardFileReferenceService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/17/26.
//

import Foundation

enum ClipboardFileReferenceError:
    LocalizedError,
    Equatable
{
    case notFileURL
    case resourceDoesNotExist
    case resourceMetadataUnavailable
    case bookmarkUnavailable
    case invalidBookmark
    case staleBookmark

    var errorDescription: String? {
        switch self {
        case .notFileURL:
            return
                "The selected item is not a local file or folder."

        case .resourceDoesNotExist:
            return
                "The selected file or folder could not be found."

        case .resourceMetadataUnavailable:
            return
                "ClipVault could not read the file or folder metadata."

        case .bookmarkUnavailable:
            return
                "ClipVault could not preserve access to the file or folder."

        case .invalidBookmark:
            return
                "ClipVault could not resolve the saved file reference."

        case .staleBookmark:
            return
                "The saved file reference is stale and must be refreshed."
        }
    }
}

struct ResolvedClipboardFileReference {
    let url: URL
    let didStartSecurityScopedAccess: Bool

    func stopAccessing() {
        guard
            didStartSecurityScopedAccess
        else {
            return
        }

        url.stopAccessingSecurityScopedResource()
    }
}

@MainActor
final class ClipboardFileReferenceService {
    static let shared =
        ClipboardFileReferenceService()

    private let bookmarkCreator:
        (URL) throws -> Data

    private let bookmarkResolver:
        (Data) throws -> (
            url: URL,
            isStale: Bool
        )

    private init() {
        bookmarkCreator = {
            fileURL in

            try fileURL.bookmarkData(
                options: [
                    .withSecurityScope,
                    .securityScopeAllowOnlyReadAccess
                ],
                includingResourceValuesForKeys: [
                    .nameKey,
                    .isDirectoryKey,
                    .fileSizeKey
                ],
                relativeTo:
                    nil
            )
        }

        bookmarkResolver = {
            bookmarkData in

            var isStale =
                false

            let resolvedURL =
                try URL(
                    resolvingBookmarkData:
                        bookmarkData,
                    options: [
                        .withSecurityScope,
                        .withoutUI
                    ],
                    relativeTo:
                        nil,
                    bookmarkDataIsStale:
                        &isStale
                )

            return (
                url:
                    resolvedURL,
                isStale:
                    isStale
            )
        }
    }

    init(
        bookmarkCreator:
            @escaping (URL) throws -> Data,
        bookmarkResolver:
            @escaping (Data) throws -> (
                url: URL,
                isStale: Bool
            )
    ) {
        self.bookmarkCreator =
            bookmarkCreator

        self.bookmarkResolver =
            bookmarkResolver
    }

    func makeReference(
        for fileURL: URL
    ) throws -> ClipboardFileReference {
        guard fileURL.isFileURL else {
            throw ClipboardFileReferenceError
                .notFileURL
        }

        let standardizedURL =
            fileURL
                .standardizedFileURL

        guard
            FileManager.default
                .fileExists(
                    atPath:
                        standardizedURL.path
                )
        else {
            throw ClipboardFileReferenceError
                .resourceDoesNotExist
        }

        let didStartAccessing =
            standardizedURL
                .startAccessingSecurityScopedResource()

        defer {
            if didStartAccessing {
                standardizedURL
                    .stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues:
            URLResourceValues

        do {
            resourceValues =
                try standardizedURL
                    .resourceValues(
                        forKeys: [
                            .nameKey,
                            .isDirectoryKey,
                            .fileSizeKey
                        ]
                    )
        } catch {
            throw ClipboardFileReferenceError
                .resourceMetadataUnavailable
        }

        guard
            let isDirectory =
                resourceValues
                    .isDirectory
        else {
            throw ClipboardFileReferenceError
                .resourceMetadataUnavailable
        }

        let bookmarkData:
            Data

        do {
            bookmarkData =
                try bookmarkCreator(
                    standardizedURL
                )
        } catch {
            throw ClipboardFileReferenceError
                .bookmarkUnavailable
        }

        let displayName =
            resourceValues.name?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return ClipboardFileReference(
            path:
                standardizedURL.path,
            displayName:
                displayName ??
                standardizedURL
                    .lastPathComponent,
            isDirectory:
                isDirectory,
            byteCount:
                isDirectory
                    ? nil
                    : resourceValues
                        .fileSize,
            bookmarkData:
                bookmarkData
        )
    }

    func makeReferences(
        for fileURLs: [URL]
    ) -> ClipboardFileReferenceBatchResult {
        var references:
            [ClipboardFileReference] = []

        var failedURLs:
            [URL] = []

        for fileURL in fileURLs {
            do {
                let reference =
                    try makeReference(
                        for:
                            fileURL
                    )

                references.append(
                    reference
                )
            } catch {
                failedURLs.append(
                    fileURL
                )
            }
        }

        return ClipboardFileReferenceBatchResult(
            references:
                references,
            failedURLs:
                failedURLs
        )
    }

    func resolve(
        _ reference:
            ClipboardFileReference
    ) throws -> ResolvedClipboardFileReference {
        guard
            let bookmarkData =
                reference.bookmarkData
        else {
            throw ClipboardFileReferenceError
                .invalidBookmark
        }

        let resolution:
            (
                url: URL,
                isStale: Bool
            )

        do {
            resolution =
                try bookmarkResolver(
                    bookmarkData
                )
        } catch {
            throw ClipboardFileReferenceError
                .invalidBookmark
        }

        guard
            !resolution.isStale
        else {
            throw ClipboardFileReferenceError
                .staleBookmark
        }

        let standardizedURL =
            resolution
                .url
                .standardizedFileURL

        guard
            FileManager.default
                .fileExists(
                    atPath:
                        standardizedURL.path
                )
        else {
            throw ClipboardFileReferenceError
                .resourceDoesNotExist
        }

        let didStartAccessing =
            standardizedURL
                .startAccessingSecurityScopedResource()

        return ResolvedClipboardFileReference(
            url:
                standardizedURL,
            didStartSecurityScopedAccess:
                didStartAccessing
        )
    }
}

struct ClipboardFileReferenceBatchResult:
    Equatable
{
    let references:
        [ClipboardFileReference]

    let failedURLs:
        [URL]

    var succeededCount: Int {
        references.count
    }

    var failedCount: Int {
        failedURLs.count
    }
}
