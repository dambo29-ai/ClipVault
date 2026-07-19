//
//  ClipboardMixedFilesPasteboardServiceTests.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/19/26.
//

import AppKit
import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardMixedFilesPasteboardServiceTests {
    @Test
    func mixedEntriesPreserveOrderAndRenameSelectedMembers()
        async throws
    {
        let rootURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "ClipboardMixedGroupTest-" +
                    UUID().uuidString,
                    isDirectory:
                        true
                )

        defer {
            try? FileManager.default
                .removeItem(
                    at:
                        rootURL
                )
        }

        try FileManager.default
            .createDirectory(
                at:
                    rootURL,
                withIntermediateDirectories:
                    true
            )

        let imageURL =
            rootURL
                .appendingPathComponent(
                    "Photo.png"
                )

        let documentURL =
            rootURL
                .appendingPathComponent(
                    "Notes.txt"
                )

        let folderURL =
            rootURL
                .appendingPathComponent(
                    "Project",
                    isDirectory:
                        true
                )

        let imageData =
            try makePNGData()

        try imageData.write(
            to:
                imageURL
        )

        try Data(
            "Notes"
                .utf8
        )
        .write(
            to:
                documentURL
        )

        try FileManager.default
            .createDirectory(
                at:
                    folderURL,
                withIntermediateDirectories:
                    true
            )

        let resolvedURLs =
            [
                documentURL,
                folderURL
            ]

        let resolverIndex =
            ResolverIndex()

        let bookmarkData =
            Data([1, 2, 3])

        let referenceService =
            ClipboardFileReferenceService(
                bookmarkCreator: {
                    _ in
                    bookmarkData
                },
                bookmarkResolver: {
                    _ in

                    let index =
                        resolverIndex.value

                    resolverIndex.value += 1

                    return (
                        url:
                            resolvedURLs[index],
                        isStale:
                            false
                    )
                }
            )

        let imageStorageService =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    rootURL
                        .appendingPathComponent(
                            "Images",
                            isDirectory:
                                true
                        )
            )

        let imagePayload =
            try await imageStorageService
                .storeImage(
                    data:
                        imageData,
                    originalFilename:
                        "Photo.png",
                    originalFileReference:
                        makeReference(
                            path:
                                imageURL.path,
                            displayName:
                                "Photo.png",
                            bookmarkData:
                                bookmarkData
                        )
                )

        let documentPayload =
            ClipboardFilesPayload(
                files: [
                    makeReference(
                        path:
                            documentURL.path,
                        displayName:
                            "Notes.txt",
                        bookmarkData:
                            bookmarkData
                    )
                ]
            )

        let folderPayload =
            ClipboardFilesPayload(
                files: [
                    makeReference(
                        path:
                            folderURL.path,
                        displayName:
                            "Project",
                        isDirectory:
                            true,
                        bookmarkData:
                            bookmarkData
                    )
                ]
            )

        let service =
            ClipboardMixedFilesPasteboardService(
                imageStorageService:
                    imageStorageService,
                fileReferenceService:
                    referenceService,
                fileExportStagingService:
                    ClipboardFileExportStagingService(
                        stagingRootURL:
                            rootURL
                                .appendingPathComponent(
                                    "Staging",
                                    isDirectory:
                                        true
                                )
                    )
            )

        let pasteboard =
            NSPasteboard(
                name:
                    NSPasteboard.Name(
                        "ClipboardMixedTest-" +
                        UUID().uuidString
                    )
            )

        let didWrite =
            try await service.writeEntries(
                [
                    .image(
                        payload:
                            imagePayload,
                        customTitle:
                            "Renamed Photo"
                    ),
                    .file(
                        payload:
                            documentPayload,
                        customTitle:
                            "Final Notes",
                        exportIdentifier:
                            UUID()
                    ),
                    .file(
                        payload:
                            folderPayload,
                        customTitle:
                            nil,
                        exportIdentifier:
                            UUID()
                    )
                ],
                to:
                    pasteboard
            )

        #expect(didWrite)

        let writtenNames =
            (
                pasteboard.readObjects(
                    forClasses: [
                        NSURL.self
                    ],
                    options: [
                        .urlReadingFileURLsOnly:
                            true
                    ]
                ) as? [NSURL]
            )?
            .map {
                ($0 as URL)
                    .lastPathComponent
            }

        #expect(
            writtenNames ==
                [
                    "Renamed Photo.png",
                    "Final Notes.txt",
                    "Project"
                ]
        )
    }

    private func makeReference(
        path:
            String,
        displayName:
            String,
        isDirectory:
            Bool = false,
        bookmarkData:
            Data
    ) -> ClipboardFileReference {
        ClipboardFileReference(
            path:
                path,
            displayName:
                displayName,
            isDirectory:
                isDirectory,
            byteCount:
                nil,
            bookmarkData:
                bookmarkData
        )
    }

    private func makePNGData()
        throws -> Data
    {
        guard
            let bitmap =
                NSBitmapImageRep(
                    bitmapDataPlanes:
                        nil,
                    pixelsWide:
                        4,
                    pixelsHigh:
                        4,
                    bitsPerSample:
                        8,
                    samplesPerPixel:
                        4,
                    hasAlpha:
                        true,
                    isPlanar:
                        false,
                    colorSpaceName:
                        .deviceRGB,
                    bytesPerRow:
                        0,
                    bitsPerPixel:
                        0
                )
        else {
            throw TestError
                .couldNotCreateImage
        }

        guard
            let data =
                bitmap.representation(
                    using:
                        .png,
                    properties:
                        [:]
                )
        else {
            throw TestError
                .couldNotCreateImage
        }

        return data
    }

    private final class ResolverIndex {
        var value = 0
    }

    private enum TestError:
        Error
    {
        case couldNotCreateImage
    }
}
