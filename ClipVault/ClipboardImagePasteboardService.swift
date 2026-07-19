//
//  ClipboardImagePasteboardService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import Foundation

struct ClipboardImagePasteboardEntry {
    let payload:
        ClipboardImagePayload

    let customTitle:
        String?
}

@MainActor
struct ClipboardImagePasteboardService {
    private let imageStorageService:
        ClipboardImageStorageService

    private let fileReferenceService:
        ClipboardFileReferenceService

    init(
        imageStorageService:
            ClipboardImageStorageService =
                .shared,
        fileReferenceService:
            ClipboardFileReferenceService? =
                nil
    ) {
        self.imageStorageService =
            imageStorageService

        self.fileReferenceService =
            fileReferenceService ??
            ClipboardFileReferenceService
                .shared
    }
    
    func writeImageFiles(
        _ entries:
            [ClipboardImagePasteboardEntry],
        to pasteboard:
            NSPasteboard
    ) async throws -> Bool {
        guard !entries.isEmpty else {
            return false
        }

        var resolvedFileReferences:
            [ResolvedClipboardFileReference] =
                []

        var fileURLs:
            [URL] = []

        do {
            for entry in entries {
                let normalizedCustomTitle =
                    entry.customTitle?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                let originalFilenameStem =
                    entry
                        .payload
                        .originalFilename
                        .map {
                            NSString(
                                string:
                                    $0
                            )
                            .deletingPathExtension
                        }
                        .flatMap {
                            let trimmedValue =
                                $0.trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )

                            return trimmedValue
                                .isEmpty
                                ? nil
                                : trimmedValue
                        }

                let fallbackFilenameStem =
                    originalFilenameStem ??
                    "Copied Image"

                if let normalizedCustomTitle,
                   !normalizedCustomTitle
                    .isEmpty
                {
                    let stagedFileURL =
                        try await imageStorageService
                            .stagedImageFileURL(
                                for:
                                    entry.payload,
                                preferredFilenameStem:
                                    normalizedCustomTitle
                            )

                    fileURLs.append(
                        stagedFileURL
                    )

                    continue
                }

                if let originalFileReference =
                    entry
                        .payload
                        .originalFileReference
                {
                    do {
                        let resolvedReference =
                            try fileReferenceService
                                .resolve(
                                    originalFileReference
                                )

                        resolvedFileReferences
                            .append(
                                resolvedReference
                            )

                        fileURLs.append(
                            resolvedReference
                                .url
                        )

                        continue
                    } catch {
                        /*
                         A missing original falls through to
                         ClipVault's managed staged copy.
                         */
                    }
                }

                let stagedFileURL =
                    try await imageStorageService
                        .stagedImageFileURL(
                            for:
                                entry.payload,
                            preferredFilenameStem:
                                fallbackFilenameStem
                        )

                fileURLs.append(
                    stagedFileURL
                )
            }
        } catch {
            stopAccessing(
                resolvedFileReferences
            )

            throw error
        }

        defer {
            stopAccessing(
                resolvedFileReferences
            )
        }

        pasteboard.clearContents()

        return pasteboard.writeObjects(
            fileURLs.map {
                $0 as NSURL
            }
        )
    }

    func writeImage(
        _ payload:
            ClipboardImagePayload,
        customTitle:
            String? = nil,
        to pasteboard:
            NSPasteboard
    ) async throws -> Bool {
        let imageData =
            try await imageStorageService
                .loadImageData(
                    for:
                        payload
                )

        let pasteboardType =
            NSPasteboard.PasteboardType(
                payload
                    .format
                    .uniformTypeIdentifier
            )

        let pasteboardItem =
            NSPasteboardItem()

        guard
            pasteboardItem.setData(
                imageData,
                forType:
                    pasteboardType
            )
        else {
            return false
        }

        var resolvedFileReference:
            ResolvedClipboardFileReference?

        let normalizedCustomTitle =
            customTitle?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let originalFilenameStem =
            payload.originalFilename
                .map {
                    NSString(
                        string:
                            $0
                    )
                    .deletingPathExtension
                }
                .flatMap {
                    let trimmedValue =
                        $0.trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                    return trimmedValue.isEmpty
                        ? nil
                        : trimmedValue
                }

        let fallbackFilenameStem =
            originalFilenameStem ??
            "Copied Image"

        let fileURLForPasteboard:
            URL

        if let normalizedCustomTitle,
           !normalizedCustomTitle.isEmpty
        {
            fileURLForPasteboard =
                try await imageStorageService
                    .stagedImageFileURL(
                        for:
                            payload,
                        preferredFilenameStem:
                            normalizedCustomTitle
                    )
        } else if let originalFileReference =
            payload.originalFileReference
        {
            resolvedFileReference =
                try? fileReferenceService
                    .resolve(
                        originalFileReference
                    )

            if let resolvedFileReference {
                fileURLForPasteboard =
                    resolvedFileReference
                        .url
            } else {
                fileURLForPasteboard =
                    try await imageStorageService
                        .stagedImageFileURL(
                            for:
                                payload,
                            preferredFilenameStem:
                                fallbackFilenameStem
                        )
            }
        } else {
            fileURLForPasteboard =
                try await imageStorageService
                    .stagedImageFileURL(
                        for:
                            payload,
                        preferredFilenameStem:
                            fallbackFilenameStem
                    )
        }

        guard
            pasteboardItem.setString(
                fileURLForPasteboard
                    .absoluteString,
                forType:
                    .fileURL
            )
        else {
            resolvedFileReference?
                .stopAccessing()

            return false
        }

        defer {
            resolvedFileReference?
                .stopAccessing()
        }

        pasteboard.clearContents()

        return pasteboard.writeObjects([
            pasteboardItem
        ])
    }
    
    private func stopAccessing(
        _ resolvedFileReferences:
            [ResolvedClipboardFileReference]
    ) {
        for resolvedFileReference in
            resolvedFileReferences
        {
            resolvedFileReference
                .stopAccessing()
        }
    }
}
