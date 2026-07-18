//
//  ClipboardFilesPasteboardService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/17/26.
//

import AppKit
import Foundation

@MainActor
struct ClipboardFilesPasteboardService {
    private let fileReferenceService:
        ClipboardFileReferenceService

    init(
        fileReferenceService:
            ClipboardFileReferenceService? =
                nil
    ) {
        self.fileReferenceService =
            fileReferenceService ??
            ClipboardFileReferenceService
                .shared
    }

    func writeFiles(
        _ payload:
            ClipboardFilesPayload,
        to pasteboard:
            NSPasteboard
    ) throws -> Bool {
        guard !payload.files.isEmpty else {
            return false
        }

        var resolvedReferences:
            [ResolvedClipboardFileReference] =
                []

        do {
            for fileReference in
                payload.files
            {
                let resolvedReference =
                    try fileReferenceService
                        .resolve(
                            fileReference
                        )

                resolvedReferences.append(
                    resolvedReference
                )
            }
        } catch {
            stopAccessing(
                resolvedReferences
            )

            throw error
        }

        defer {
            stopAccessing(
                resolvedReferences
            )
        }

        let fileURLs =
            resolvedReferences.map {
                $0.url
            }

        let pasteboardObjects =
            fileURLs.map {
                $0 as NSURL
            }

        pasteboard.clearContents()

        return pasteboard.writeObjects(
            pasteboardObjects
        )
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
