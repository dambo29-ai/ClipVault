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
    case resourceUnavailable
    case resourceMetadataUnavailable
    case bookmarkUnavailable
    case invalidBookmark
    case staleBookmark

    var errorDescription: String? {
        switch self {
        case .notFileURL:
            return
                "The selected item is not a local file or folder."

        case .resourceUnavailable:
            return
                "The file or folder is currently unavailable. It may have been moved, deleted, or stored on a disconnected drive or network location."

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
                "ClipVault’s saved access to this file or folder is no longer valid. The original item may have moved or its storage location may have changed."
        }
    }
}

struct ResolvedClipboardFileReference {
    let url: URL
    let didStartSecurityScopedAccess: Bool

    private let securityScopedAccessStopper:
        (URL) -> Void

    init(
        url: URL,
        didStartSecurityScopedAccess:
            Bool,
        securityScopedAccessStopper:
            @escaping (URL) -> Void = {
                fileURL in

                fileURL
                    .stopAccessingSecurityScopedResource()
            }
    ) {
        self.url =
            url

        self.didStartSecurityScopedAccess =
            didStartSecurityScopedAccess

        self.securityScopedAccessStopper =
            securityScopedAccessStopper
    }

    func stopAccessing() {
        guard
            didStartSecurityScopedAccess
        else {
            return
        }

        securityScopedAccessStopper(
            url
        )
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

    private let securityScopedAccessStarter:
        (URL) -> Bool

    private let securityScopedAccessStopper:
        (URL) -> Void

    private let symbolicLinkDestinationReader:
        (String) throws -> String

    private let symbolicLinkStorageService:
        ClipboardSymbolicLinkStorageService

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

        securityScopedAccessStarter = {
            fileURL in

            fileURL
                .startAccessingSecurityScopedResource()
        }

        securityScopedAccessStopper = {
            fileURL in

            fileURL
                .stopAccessingSecurityScopedResource()
        }

        symbolicLinkDestinationReader = {
            path in

            try FileManager.default
                .destinationOfSymbolicLink(
                    atPath:
                        path
                )
        }

        symbolicLinkStorageService =
            ClipboardSymbolicLinkStorageService
                .shared
    }

    init(
        bookmarkCreator:
            @escaping (URL) throws -> Data,
        bookmarkResolver:
            @escaping (Data) throws -> (
                url: URL,
                isStale: Bool
            ),
        securityScopedAccessStarter:
            @escaping (URL) -> Bool = {
                fileURL in

                fileURL
                    .startAccessingSecurityScopedResource()
            },
        securityScopedAccessStopper:
            @escaping (URL) -> Void = {
                fileURL in

                fileURL
                    .stopAccessingSecurityScopedResource()
            },
        symbolicLinkDestinationReader:
            @escaping (String) throws
                -> String = {
                    path in

                    try FileManager.default
                        .destinationOfSymbolicLink(
                            atPath:
                                path
                        )
                },
        symbolicLinkStorageService:
            ClipboardSymbolicLinkStorageService? =
                nil
    ) {
        self.bookmarkCreator =
            bookmarkCreator

        self.bookmarkResolver =
            bookmarkResolver

        self.securityScopedAccessStarter =
            securityScopedAccessStarter

        self.securityScopedAccessStopper =
            securityScopedAccessStopper

        self.symbolicLinkDestinationReader =
            symbolicLinkDestinationReader

        self.symbolicLinkStorageService =
            symbolicLinkStorageService ??
            ClipboardSymbolicLinkStorageService
                .shared
    }

    func makeReference(
        for fileURL:
            URL
    ) throws -> ClipboardFileReference {
        guard fileURL.isFileURL else {
            throw ClipboardFileReferenceError
                .notFileURL
        }

        let standardizedURL =
            fileURL
                .standardizedFileURL

        if Self.isSymbolicLink(
            at:
                standardizedURL
        ) {
            let destination:
                String

            do {
                destination =
                    try symbolicLinkDestinationReader(
                        standardizedURL.path
                    )
            } catch {
                throw ClipboardFileReferenceError
                    .resourceMetadataUnavailable
            }

            return ClipboardFileReference(
                path:
                    standardizedURL.path,
                displayName:
                    standardizedURL
                        .lastPathComponent,
                isDirectory:
                    false,
                byteCount:
                    nil,
                bookmarkData:
                    nil,
                symbolicLinkIdentifier:
                    UUID(),
                symbolicLinkDestination:
                    destination
            )
        }

        guard
            FileManager.default
                .fileExists(
                    atPath:
                        standardizedURL.path
                )
        else {
            throw ClipboardFileReferenceError
                .resourceUnavailable
        }

        let didStartAccessing =
            securityScopedAccessStarter(
                standardizedURL
            )

        defer {
            if didStartAccessing {
                securityScopedAccessStopper(
                    standardizedURL
                )
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
        for fileURLs:
            [URL]
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
        if reference.isSymbolicLink {
            let symbolicLinkURL =
                try symbolicLinkStorageService
                    .materializedURL(
                        for:
                            reference
                    )

            return ResolvedClipboardFileReference(
                url:
                    symbolicLinkURL,
                didStartSecurityScopedAccess:
                    false,
                securityScopedAccessStopper:
                    securityScopedAccessStopper
            )
        }

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
                .resourceUnavailable
        }

        let didStartAccessing =
            securityScopedAccessStarter(
                standardizedURL
            )

        return ResolvedClipboardFileReference(
            url:
                standardizedURL,
            didStartSecurityScopedAccess:
                didStartAccessing,
            securityScopedAccessStopper:
                securityScopedAccessStopper
        )
    }

    private nonisolated static func isSymbolicLink(
        at fileURL:
            URL
    ) -> Bool {
        guard
            let attributes =
                try? FileManager.default
                    .attributesOfItem(
                        atPath:
                            fileURL.path
                    ),
            let fileType =
                attributes[
                    .type
                ] as? FileAttributeType
        else {
            return false
        }

        return fileType ==
            .typeSymbolicLink
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
