//
//  ClipboardImagePasteboardService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import Foundation

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

        let managedImageFileURL =
            try await imageStorageService
                .imageFileURL(
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

        var fileURLForPasteboard =
            managedImageFileURL

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
            }
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
}
