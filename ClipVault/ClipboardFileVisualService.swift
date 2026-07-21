//
//  ClipboardFileVisualService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/20/26.
//

import AppKit
import Foundation
import QuickLookThumbnailing

enum ClipboardFileVisualSource:
    Equatable
{
    case quickLookThumbnail
    case workspaceIcon
}

struct ClipboardFileVisual {
    let image:
        NSImage

    let source:
        ClipboardFileVisualSource
}

@MainActor
final class ClipboardFileVisualService {
    typealias ThumbnailLoader =
        @MainActor (
            URL,
            CGSize,
            CGFloat
        ) async -> NSImage?

    typealias WorkspaceIconLoader =
        @MainActor (
            [String]
        ) -> NSImage?

    static let shared =
        ClipboardFileVisualService()

    private let fileReferenceService:
        ClipboardFileReferenceService

    private let thumbnailLoader:
        ThumbnailLoader

    private let workspaceIconLoader:
        WorkspaceIconLoader

    convenience init() {
        self.init(
            fileReferenceService:
                .shared,
            thumbnailLoader:
                nil,
            workspaceIconLoader:
                nil
        )
    }

    init(
        fileReferenceService:
            ClipboardFileReferenceService,
        thumbnailLoader:
            ThumbnailLoader? = nil,
        workspaceIconLoader:
            WorkspaceIconLoader? = nil
    ) {
        self.fileReferenceService =
            fileReferenceService

        self.thumbnailLoader =
            thumbnailLoader ??
            Self.loadQuickLookThumbnail

        self.workspaceIconLoader =
            workspaceIconLoader ??
            Self.loadWorkspaceIcon
    }

    func visual(
        for payload:
            ClipboardFilesPayload,
        size:
            CGSize,
        scale:
            CGFloat
    ) async -> ClipboardFileVisual {
        guard
            let firstReference =
                payload.files.first
        else {
            return ClipboardFileVisual(
                image:
                    Self.genericDocumentIcon(),
                source:
                    .workspaceIcon
            )
        }

        /*
         Finder provides a combined icon for a group.
         Do not arbitrarily thumbnail only the first
         member of a grouped File clip.
         */
        guard
            payload.files.count == 1
        else {
            return ClipboardFileVisual(
                image:
                    workspaceIcon(
                        for:
                            payload.files.map {
                                $0.path
                            }
                    ),
                source:
                    .workspaceIcon
            )
        }

        /*
         Folders and symbolic links should retain their
         native Finder identity instead of displaying
         the contents of a resolved target.
         */
        guard
            !firstReference.isDirectory,
            !firstReference.isSymbolicLink
        else {
            return ClipboardFileVisual(
                image:
                    workspaceIcon(
                        for: [
                            firstReference.path
                        ]
                    ),
                source:
                    .workspaceIcon
            )
        }

        do {
            let resolvedReference =
                try fileReferenceService
                    .resolve(
                        firstReference
                    )

            defer {
                resolvedReference
                    .stopAccessing()
            }

            if let thumbnail =
                await thumbnailLoader(
                    resolvedReference.url,
                    size,
                    scale
                )
            {
                return ClipboardFileVisual(
                    image:
                        thumbnail,
                    source:
                        .quickLookThumbnail
                )
            }

            return ClipboardFileVisual(
                image:
                    workspaceIcon(
                        for: [
                            resolvedReference
                                .url
                                .path
                        ]
                    ),
                source:
                    .workspaceIcon
            )
        } catch {
            /*
             Even when the original is unavailable,
             macOS may still provide a meaningful icon
             from the saved path or extension.
             */
            return ClipboardFileVisual(
                image:
                    workspaceIcon(
                        for: [
                            firstReference.path
                        ]
                    ),
                source:
                    .workspaceIcon
            )
        }
    }

    private func workspaceIcon(
        for paths:
            [String]
    ) -> NSImage {
        workspaceIconLoader(
            paths
        ) ??
        Self.genericDocumentIcon()
    }

    private static func loadWorkspaceIcon(
        for paths:
            [String]
    ) -> NSImage? {
        guard !paths.isEmpty else {
            return nil
        }

        return NSWorkspace.shared
            .icon(
                forFiles:
                    paths
            )
    }

    private static func loadQuickLookThumbnail(
        for fileURL:
            URL,
        size:
            CGSize,
        scale:
            CGFloat
    ) async -> NSImage? {
        let request =
            QLThumbnailGenerator.Request(
                fileAt:
                    fileURL,
                size:
                    size,
                scale:
                    scale,
                representationTypes:
                    .all
            )

        let cgImage:
            CGImage? =
                await withCheckedContinuation {
                    continuation in

                    QLThumbnailGenerator
                        .shared
                        .generateBestRepresentation(
                            for:
                                request
                        ) {
                            representation,
                            _ in

                            continuation.resume(
                                returning:
                                    representation?
                                        .cgImage
                            )
                        }
                }

        guard let cgImage else {
            return nil
        }

        return NSImage(
            cgImage:
                cgImage,
            size:
                size
        )
    }

    private static func genericDocumentIcon()
        -> NSImage
    {
        NSImage(
            systemSymbolName:
                "doc.fill",
            accessibilityDescription:
                "File"
        ) ??
        NSImage()
    }
}
