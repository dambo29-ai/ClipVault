//
//  ClipboardFileExportStagingService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/19/26.
//

import Foundation

enum ClipboardFileExportStagingError:
    LocalizedError
{
    case emptyFilename
    case sourceUnavailable
    case stagingUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyFilename:
            return
                "The renamed file or folder has no usable filename."

        case .sourceUnavailable:
            return
                "The original file or folder could not be accessed."

        case .stagingUnavailable:
            return
                "ClipVault could not prepare the renamed copy."
        }
    }
}

struct ClipboardFileExportStagingService:
    Sendable
{
    private let stagingRootURL:
        URL

    nonisolated init(
        stagingRootURL:
            URL? = nil
    ) {
        if let stagingRootURL {
            self.stagingRootURL =
                stagingRootURL
        } else {
            self.stagingRootURL =
                FileManager.default
                    .urls(
                        for:
                            .cachesDirectory,
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
                        "File Paste Exports",
                        isDirectory:
                            true
                    ) ??
                FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "ClipVault File Paste Exports",
                        isDirectory:
                            true
                    )
        }
    }

    nonisolated func stagedCopy(
        of sourceURL:
            URL,
        customTitle:
            String,
        exportIdentifier:
            UUID
    ) async throws -> URL {
        let stagingRootURL =
            stagingRootURL

        return try await Task.detached(
            priority:
                .userInitiated
        ) {
            try Self.makeStagedCopy(
                of:
                    sourceURL,
                customTitle:
                    customTitle,
                exportIdentifier:
                    exportIdentifier,
                stagingRootURL:
                    stagingRootURL
            )
        }
        .value
    }

    private nonisolated static func makeStagedCopy(
        of sourceURL:
            URL,
        customTitle:
            String,
        exportIdentifier:
            UUID,
        stagingRootURL:
            URL
    ) throws -> URL {
        let fileManager =
            FileManager.default

        let standardizedSourceURL =
            sourceURL.standardizedFileURL

        guard
            fileManager.fileExists(
                atPath:
                    standardizedSourceURL.path
            )
        else {
            throw ClipboardFileExportStagingError
                .sourceUnavailable
        }

        let resourceValues =
            try standardizedSourceURL
                .resourceValues(
                    forKeys: [
                        .isDirectoryKey
                    ]
                )

        let isDirectory =
            resourceValues.isDirectory ??
            false

        let sanitizedTitle =
            sanitizedFilenameComponent(
                customTitle
            )

        guard !sanitizedTitle.isEmpty else {
            throw ClipboardFileExportStagingError
                .emptyFilename
        }

        let filenameExtension =
            standardizedSourceURL
                .pathExtension

        let stagedFilename:
            String

        if isDirectory ||
            filenameExtension.isEmpty
        {
            stagedFilename =
                sanitizedTitle
        } else {
            stagedFilename =
                "\(sanitizedTitle).\(filenameExtension)"
        }

        let exportDirectoryURL =
            stagingRootURL
                .appendingPathComponent(
                    exportIdentifier
                        .uuidString,
                    isDirectory:
                        true
                )

        do {
            if fileManager.fileExists(
                atPath:
                    exportDirectoryURL.path
            ) {
                try fileManager.removeItem(
                    at:
                        exportDirectoryURL
                )
            }

            try fileManager.createDirectory(
                at:
                    exportDirectoryURL,
                withIntermediateDirectories:
                    true
            )

            let stagedURL =
                exportDirectoryURL
                    .appendingPathComponent(
                        stagedFilename,
                        isDirectory:
                            isDirectory
                    )

            try fileManager.copyItem(
                at:
                    standardizedSourceURL,
                to:
                    stagedURL
            )

            return stagedURL
        } catch {
            throw ClipboardFileExportStagingError
                .stagingUnavailable
        }
    }

    private nonisolated static func sanitizedFilenameComponent(
        _ value:
            String
    ) -> String {
        let invalidCharacters =
            CharacterSet(
                charactersIn:
                    "/:"
            )
            .union(
                .controlCharacters
            )

        let sanitizedValue =
            value
                .components(
                    separatedBy:
                        invalidCharacters
                )
                .joined(
                    separator:
                        "-"
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return String(
            sanitizedValue
                .prefix(
                    180
                )
        )
    }
}
