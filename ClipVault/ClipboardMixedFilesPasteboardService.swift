//
//  ClipboardMixedFilesPasteboardService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/19/26.
//

import AppKit
import Foundation

enum ClipboardMixedFilePasteboardEntry {
    case image(
        payload:
            ClipboardImagePayload,
        customTitle:
            String?
    )

    case file(
        payload:
            ClipboardFilesPayload,
        customTitle:
            String?,
        exportIdentifier:
            UUID
    )
}

@MainActor
final class ClipboardMixedFilesPasteboardService {
    private let imageStorageService:
        ClipboardImageStorageService

    private let fileReferenceService:
        ClipboardFileReferenceService

    private let fileExportStagingService:
        ClipboardFileExportStagingService

    private var activePasteboardReferences:
        [ResolvedClipboardFileReference] =
            []

    init(
        imageStorageService:
            ClipboardImageStorageService =
                .shared,
        fileReferenceService:
            ClipboardFileReferenceService? =
                nil,
        fileExportStagingService:
            ClipboardFileExportStagingService? =
                nil
    ) {
        self.imageStorageService =
            imageStorageService

        self.fileReferenceService =
            fileReferenceService ??
            ClipboardFileReferenceService
                .shared

        self.fileExportStagingService =
            fileExportStagingService ??
            ClipboardFileExportStagingService()
    }

    func writeEntries(
        _ entries:
            [ClipboardMixedFilePasteboardEntry],
        to pasteboard:
            NSPasteboard
    ) async throws -> Bool {
        guard !entries.isEmpty else {
            return false
        }

        releasePasteboardAccess()

        var resolvedReferences:
            [ResolvedClipboardFileReference] =
                []

        var fileURLs:
            [URL] = []

        do {
            for entry in entries {
                switch entry {
                case let .image(
                    payload,
                    customTitle
                ):
                    let imageURL =
                        try await imageFileURL(
                            for:
                                payload,
                            customTitle:
                                customTitle,
                            resolvedReferences:
                                &resolvedReferences
                        )

                    fileURLs.append(
                        imageURL
                    )

                case let .file(
                    payload,
                    customTitle,
                    exportIdentifier
                ):
                    guard
                        payload.files.count == 1,
                        let fileReference =
                            payload.files.first
                    else {
                        stopAccessing(
                            resolvedReferences
                        )

                        return false
                    }

                    let resolvedReference =
                        try fileReferenceService
                            .resolve(
                                fileReference
                            )

                    resolvedReferences.append(
                        resolvedReference
                    )

                    let normalizedCustomTitle =
                        normalizedTitle(
                            customTitle
                        )

                    if let normalizedCustomTitle {
                        let stagedURL =
                            try await fileExportStagingService
                                .stagedCopy(
                                    of:
                                        resolvedReference.url,
                                    customTitle:
                                        normalizedCustomTitle,
                                    exportIdentifier:
                                        exportIdentifier
                                )

                        fileURLs.append(
                            stagedURL
                        )
                    } else {
                        fileURLs.append(
                            resolvedReference.url
                        )
                    }
                }
            }
        } catch {
            stopAccessing(
                resolvedReferences
            )

            throw error
        }

        pasteboard.clearContents()

        let didWrite =
            pasteboard.writeObjects(
                fileURLs.map {
                    $0 as NSURL
                }
            )

        if didWrite {
            activePasteboardReferences =
                resolvedReferences
        } else {
            stopAccessing(
                resolvedReferences
            )
        }

        return didWrite
    }
    
    func releasePasteboardAccess() {
        stopAccessing(
            activePasteboardReferences
        )

        activePasteboardReferences = []
    }

    private func imageFileURL(
        for payload:
            ClipboardImagePayload,
        customTitle:
            String?,
        resolvedReferences:
            inout [
                ResolvedClipboardFileReference
            ]
    ) async throws -> URL {
        if let normalizedCustomTitle =
            normalizedTitle(
                customTitle
            )
        {
            return try await imageStorageService
                .stagedImageFileURL(
                    for:
                        payload,
                    preferredFilenameStem:
                        normalizedCustomTitle
                )
        }

        if let originalFileReference =
            payload.originalFileReference
        {
            do {
                let resolvedReference =
                    try fileReferenceService
                        .resolve(
                            originalFileReference
                        )

                resolvedReferences.append(
                    resolvedReference
                )

                return resolvedReference.url
            } catch {
                /*
                 Missing originals use ClipVault's
                 managed image as a staged copy.
                 */
            }
        }

        return try await imageStorageService
            .stagedImageFileURL(
                for:
                    payload,
                preferredFilenameStem:
                    fallbackImageFilenameStem(
                        for:
                            payload
                    )
            )
    }

    private func fallbackImageFilenameStem(
        for payload:
            ClipboardImagePayload
    ) -> String {
        guard
            let originalFilename =
                payload.originalFilename
        else {
            return "Copied Image"
        }

        let filenameStem =
            NSString(
                string:
                    originalFilename
            )
            .deletingPathExtension
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        return filenameStem.isEmpty
            ? "Copied Image"
            : filenameStem
    }

    private func normalizedTitle(
        _ value:
            String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue =
            value.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        return trimmedValue.isEmpty
            ? nil
            : trimmedValue
    }

    private func stopAccessing(
        _ resolvedReferences:
            [ResolvedClipboardFileReference]
    ) {
        for resolvedReference in
            resolvedReferences
        {
            resolvedReference
                .stopAccessing()
        }
    }
}
