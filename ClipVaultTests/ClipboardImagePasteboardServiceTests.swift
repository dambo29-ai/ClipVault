//
//  ClipboardImagePasteboardServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import ClipVault

@MainActor
struct ClipboardImagePasteboardServiceTests {
    @Test
    func storedImageWritesOriginalBytesAndType()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let storageService =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let imageData =
            try makePNGData(
                width: 8,
                height: 6
            )

        let payload =
            try await storageService
                .storeImage(
                    data: imageData
                )

        let pasteboard =
            makePasteboard()

        let pasteboardService =
            ClipboardImagePasteboardService(
                imageStorageService:
                    storageService
            )

        let didWrite =
            try await pasteboardService
                .writeImage(
                    payload,
                    to: pasteboard
                )

        #expect(didWrite)

        let storedType =
            NSPasteboard.PasteboardType(
                UTType.png.identifier
            )

        #expect(
            pasteboard.data(
                forType: storedType
            ) ==
                imageData
        )
    }
    
    @Test
    func storedImageWithoutOriginalFileWritesFriendlyStagedFileURL()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let storageService =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let imageData =
            try makePNGData(
                width: 7,
                height: 5
            )

        let payload =
            try await storageService
                .storeImage(
                    data:
                        imageData
                )

        let pasteboard =
            makePasteboard()

        let pasteboardService =
            ClipboardImagePasteboardService(
                imageStorageService:
                    storageService
            )

        let didWrite =
            try await pasteboardService
                .writeImage(
                    payload,
                    to:
                        pasteboard
                )

        #expect(didWrite)

        let writtenFileURLs =
            pasteboard.readObjects(
                forClasses: [
                    NSURL.self
                ],
                options: [
                    .urlReadingFileURLsOnly:
                        true
                ]
            ) as? [NSURL]

        #expect(
            writtenFileURLs?
                .first
                .map {
                    ($0 as URL)
                        .lastPathComponent
                } ==
            "Copied Image.png"
        )

        let storedType =
            NSPasteboard.PasteboardType(
                UTType.png.identifier
            )

        #expect(
            pasteboard.data(
                forType:
                    storedType
            ) ==
            imageData
        )
    }
    
    @Test
    func generatedJPEGUsesJPGFilenameExtension()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let storageService =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let tiffData =
            try makeOpaqueTIFFData(
                width:
                    30,
                height:
                    20
            )

        let payload =
            try await storageService
                .storeClipboardImage(
                    data:
                        tiffData
                )

        #expect(
            payload.format
                .filenameExtension ==
            "jpeg"
        )

        let pasteboard =
            makePasteboard()

        let pasteboardService =
            ClipboardImagePasteboardService(
                imageStorageService:
                    storageService
            )

        let didWrite =
            try await pasteboardService
                .writeImage(
                    payload,
                    to:
                        pasteboard
                )

        #expect(didWrite)

        let writtenFileURLs =
            pasteboard.readObjects(
                forClasses: [
                    NSURL.self
                ],
                options: [
                    .urlReadingFileURLsOnly:
                        true
                ]
            ) as? [NSURL]

        #expect(
            writtenFileURLs?
                .first
                .map {
                    ($0 as URL)
                        .lastPathComponent
                } ==
            "Copied Image.jpg"
        )
    }
    
    @Test
    func customTitleWritesStagedFileWithCustomFilename()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let storageService =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let imageData =
            try makePNGData(
                width:
                    9,
                height:
                    7
            )

        let payload =
            try await storageService
                .storeImage(
                    data:
                        imageData,
                    originalFilename:
                        "Original Image.png"
                )

        let pasteboard =
            makePasteboard()

        let pasteboardService =
            ClipboardImagePasteboardService(
                imageStorageService:
                    storageService
            )

        let didWrite =
            try await pasteboardService
                .writeImage(
                    payload,
                    customTitle:
                        "Kitchen / Backsplash: Option",
                    to:
                        pasteboard
                )

        #expect(didWrite)

        let writtenFileURLs =
            pasteboard.readObjects(
                forClasses: [
                    NSURL.self
                ],
                options: [
                    .urlReadingFileURLsOnly:
                        true
                ]
            ) as? [NSURL]

        let writtenFileURL =
            writtenFileURLs?
                .first
                .map {
                    $0 as URL
                }

        #expect(
            writtenFileURL?
                .lastPathComponent ==
            "Kitchen - Backsplash- Option.png"
        )

        #expect(
            writtenFileURL?
                .lastPathComponent !=
            "Original Image.png"
        )

        #expect(
            writtenFileURL.map {
                FileManager.default
                    .fileExists(
                        atPath:
                            $0.path
                    )
            } ==
            true
        )

        #expect(
            writtenFileURL.flatMap {
                try? Data(
                    contentsOf:
                        $0
                )
            } ==
            imageData
        )
    }

    @Test
    func missingImageDoesNotClearExistingClipboard()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let storageService =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let payload =
            try await storageService
                .storeImage(
                    data:
                        makePNGData(
                            width: 4,
                            height: 4
                        )
                )

        try await storageService
            .deleteImage(
                for: payload
            )

        let pasteboard =
            makePasteboard()

        pasteboard.clearContents()

        pasteboard.setString(
            "Existing clipboard value",
            forType: .string
        )

        let pasteboardService =
            ClipboardImagePasteboardService(
                imageStorageService:
                    storageService
            )

        do {
            _ = try await pasteboardService
                .writeImage(
                    payload,
                    to: pasteboard
                )

            Issue.record(
                "Expected the missing image to throw an error."
            )
        } catch let error
            as ClipboardImageStorageError
        {
            #expect(
                error == .storedImageMissing
            )
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        #expect(
            pasteboard.string(
                forType: .string
            ) ==
                "Existing clipboard value"
        )
    }

    @Test
    func corruptedImageDoesNotClearExistingClipboard()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let storageService =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let payload =
            try await storageService
                .storeImage(
                    data:
                        makePNGData(
                            width: 5,
                            height: 3
                        )
                )

        let imageFileURL =
            try await storageService
                .imageFileURL(
                    for: payload
                )

        try Data(
            "Corrupted image".utf8
        )
        .write(
            to: imageFileURL,
            options: [.atomic]
        )

        let pasteboard =
            makePasteboard()

        pasteboard.clearContents()

        pasteboard.setString(
            "Existing clipboard value",
            forType: .string
        )

        let pasteboardService =
            ClipboardImagePasteboardService(
                imageStorageService:
                    storageService
            )

        do {
            _ = try await pasteboardService
                .writeImage(
                    payload,
                    to: pasteboard
                )

            Issue.record(
                "Expected the corrupted image to throw an error."
            )
        } catch let error
            as ClipboardImageStorageError
        {
            #expect(
                error ==
                    .storedImageCorrupted
            )
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        #expect(
            pasteboard.string(
                forType: .string
            ) ==
                "Existing clipboard value"
        )
    }
    
    private func makeOpaqueTIFFData(
        width: Int,
        height: Int
    ) throws -> Data {
        guard
            let bitmap =
                NSBitmapImageRep(
                    bitmapDataPlanes:
                        nil,
                    pixelsWide:
                        width,
                    pixelsHigh:
                        height,
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
            throw TestImageError
                .couldNotCreateImage
        }

        let fillColor =
            NSColor(
                calibratedRed:
                    0.25,
                green:
                    0.55,
                blue:
                    0.85,
                alpha:
                    1.0
            )

        for y in 0..<height {
            for x in 0..<width {
                bitmap.setColor(
                    fillColor,
                    atX:
                        x,
                    y:
                        y
                )
            }
        }

        guard
            let data =
                bitmap.representation(
                    using:
                        .tiff,
                    properties:
                        [:]
                )
        else {
            throw TestImageError
                .couldNotCreateImage
        }

        return data
    }

    private func makePNGData(
        width: Int,
        height: Int
    ) throws -> Data {
        guard
            let bitmap =
                NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: width,
                    pixelsHigh: height,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName:
                        .deviceRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                ),
            let imageData =
                bitmap.representation(
                    using: .png,
                    properties: [:]
                )
        else {
            throw TestImageError
                .couldNotCreateImage
        }

        return imageData
    }

    private func makePasteboard()
        -> NSPasteboard
    {
        NSPasteboard(
            name:
                NSPasteboard.Name(
                    "ClipboardImagePasteboardServiceTests-" +
                    UUID().uuidString
                )
        )
    }

    private func makeTestDirectory()
        -> URL
    {
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "ClipboardImagePasteboardServiceTests-" +
                    UUID().uuidString,
                isDirectory: true
            )
    }

    private func removeTestDirectory(
        _ directoryURL: URL
    ) {
        try? FileManager.default
            .removeItem(
                at: directoryURL
            )
    }
}

private enum TestImageError: Error {
    case couldNotCreateImage
}
