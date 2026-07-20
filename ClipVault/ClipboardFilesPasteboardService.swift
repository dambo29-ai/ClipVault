//
//  ClipboardFilesPasteboardService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/17/26.
//

import AppKit
import Foundation

struct ClipboardFilesPasteboardEntry {
    let payload:
        ClipboardFilesPayload

    let customTitle:
        String?

    let exportIdentifier:
        UUID
}

@MainActor
final class ClipboardFilesPasteboardService {
    private let fileReferenceService:
        ClipboardFileReferenceService

    private let exportStagingService:
        ClipboardFileExportStagingService

    private var activePasteboardReferences:
        [ResolvedClipboardFileReference] =
            []

    init(
        fileReferenceService:
            ClipboardFileReferenceService? =
                nil,
        exportStagingService:
            ClipboardFileExportStagingService? =
                nil
    ) {
        self.fileReferenceService =
            fileReferenceService ??
            ClipboardFileReferenceService
                .shared

        self.exportStagingService =
            exportStagingService ??
            ClipboardFileExportStagingService()
    }
    
    func writeFileEntries(
        _ entries:
            [ClipboardFilesPasteboardEntry],
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
                guard
                    entry.payload.files.count == 1,
                    let fileReference =
                        entry.payload.files.first
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
                    entry.customTitle?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                if let normalizedCustomTitle,
                   !normalizedCustomTitle.isEmpty
                {
                    let stagedURL =
                        try await exportStagingService
                            .stagedCopy(
                                of:
                                    resolvedReference.url,
                                customTitle:
                                    normalizedCustomTitle,
                                exportIdentifier:
                                    entry.exportIdentifier
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

    func writeFiles(
        _ payload:
            ClipboardFilesPayload,
        customTitle:
            String? = nil,
        exportIdentifier:
            UUID? = nil,
        to pasteboard:
            NSPasteboard
    ) async throws -> Bool {
        guard !payload.files.isEmpty else {
            return false
        }

        releasePasteboardAccess()

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

        let normalizedCustomTitle =
            customTitle?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let fileURLs:
            [URL]

        do {
            if
                payload.files.count == 1,
                resolvedReferences.count == 1,
                let normalizedCustomTitle,
                !normalizedCustomTitle.isEmpty
            {
                let stagedURL =
                    try await exportStagingService
                        .stagedCopy(
                            of:
                                resolvedReferences[0]
                                    .url,
                            customTitle:
                                normalizedCustomTitle,
                            exportIdentifier:
                                exportIdentifier ??
                                UUID()
                        )

                fileURLs = [
                    stagedURL
                ]
            } else {
                fileURLs =
                    resolvedReferences.map {
                        $0.url
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
