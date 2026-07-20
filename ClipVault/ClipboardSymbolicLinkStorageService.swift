//
//  ClipboardSymbolicLinkStorageService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/20/26.
//

import Foundation

enum ClipboardSymbolicLinkStorageError:
    LocalizedError
{
    case invalidReference
    case storageUnavailable
    case reconstructionFailed

    var errorDescription: String? {
        switch self {
        case .invalidReference:
            return
                "The saved symbolic-link information is invalid."

        case .storageUnavailable:
            return
                "ClipVault could not access symbolic-link storage."

        case .reconstructionFailed:
            return
                "ClipVault could not reconstruct the symbolic link."
        }
    }
}

struct ClipboardSymbolicLinkStorageService:
    Sendable
{
    static let shared =
        ClipboardSymbolicLinkStorageService()

    private let storageRootURL:
        URL

    nonisolated init(
        storageRootURL:
            URL? = nil
    ) {
        if let storageRootURL {
            self.storageRootURL =
                storageRootURL
        } else {
            self.storageRootURL =
                FileManager.default
                    .urls(
                        for:
                            .applicationSupportDirectory,
                        in:
                            .userDomainMask
                    )
                    .first?
                    .appendingPathComponent(
                        "ClipVault",
                        isDirectory:
                            true
                    )
                    .appendingPathComponent(
                        "Symbolic Links",
                        isDirectory:
                            true
                    ) ??
                FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "ClipVault Symbolic Links",
                        isDirectory:
                            true
                    )
        }
    }

    nonisolated func materializedURL(
        for reference:
            ClipboardFileReference
    ) throws -> URL {
        guard
            let identifier =
                reference
                    .symbolicLinkIdentifier,
            let destination =
                reference
                    .symbolicLinkDestination
        else {
            throw ClipboardSymbolicLinkStorageError
                .invalidReference
        }

        let fileManager =
            FileManager.default

        let directoryURL =
            storageRootURL
                .appendingPathComponent(
                    identifier.uuidString,
                    isDirectory:
                        true
                )

        let filename =
            reference.displayName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !filename.isEmpty else {
            throw ClipboardSymbolicLinkStorageError
                .invalidReference
        }

        let symbolicLinkURL =
            directoryURL
                .appendingPathComponent(
                    filename,
                    isDirectory:
                        false
                )

        do {
            try fileManager.createDirectory(
                at:
                    directoryURL,
                withIntermediateDirectories:
                    true
            )

            if fileManager.fileExists(
                atPath:
                    symbolicLinkURL.path
            ) ||
                Self.isSymbolicLink(
                    at:
                        symbolicLinkURL
                )
            {
                try fileManager.removeItem(
                    at:
                        symbolicLinkURL
                )
            }

            try fileManager.createSymbolicLink(
                atPath:
                    symbolicLinkURL.path,
                withDestinationPath:
                    destination
            )

            return symbolicLinkURL
        } catch {
            throw ClipboardSymbolicLinkStorageError
                .reconstructionFailed
        }
    }

    nonisolated func deleteMaterializedLink(
        for reference:
            ClipboardFileReference
    ) throws {
        guard
            let identifier =
                reference
                    .symbolicLinkIdentifier
        else {
            return
        }

        let directoryURL =
            storageRootURL
                .appendingPathComponent(
                    identifier.uuidString,
                    isDirectory:
                        true
                )

        guard
            FileManager.default.fileExists(
                atPath:
                    directoryURL.path
            )
        else {
            return
        }

        try FileManager.default.removeItem(
            at:
                directoryURL
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
