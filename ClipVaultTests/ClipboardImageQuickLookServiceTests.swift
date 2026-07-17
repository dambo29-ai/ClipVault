//
//  ClipboardImageQuickLookServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardImageQuickLookServiceTests {
    @Test
    func validStoredImageCanPreparePreview()
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
                            width: 8,
                            height: 6
                        )
                )

        let fileURL =
            try await storageService
                .imageFileURL(
                    for: payload
                )

        _ =
            try await storageService
                .loadImageData(
                    for: payload
                )

        #expect(
            FileManager.default
                .fileExists(
                    atPath:
                        fileURL.path
                )
        )

        #expect(
            fileURL.lastPathComponent ==
                payload.storedFilename
        )
    }

    @Test
    func missingStoredImageCannotPreparePreview()
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

        do {
            _ =
                try await storageService
                    .loadImageData(
                        for: payload
                    )

            Issue.record(
                "Expected the missing image to prevent preview preparation."
            )
        } catch let error
            as ClipboardImageStorageError
        {
            #expect(
                error ==
                    .storedImageMissing
            )
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }
    }

    private func makePNGData(
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

    private func makeTestDirectory()
        -> URL
    {
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "ClipboardImageQuickLookServiceTests-" +
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

private enum TestImageError:
    Error
{
    case couldNotCreateImage
}
