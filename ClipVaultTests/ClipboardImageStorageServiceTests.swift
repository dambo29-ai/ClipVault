//
//  ClipboardImageStorageServiceTests.swift
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
struct ClipboardImageStorageServiceTests {
    @Test
    func storingImageCreatesManagedFileAndMetadata()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let service =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let imageData =
            try makePNGData(
                width: 4,
                height: 3
            )

        let payload =
            try await service.storeImage(
                data: imageData,
                originalFilename:
                    "  source-image.png  "
            )

        #expect(payload.pixelWidth == 4)
        #expect(payload.pixelHeight == 3)
        #expect(payload.byteCount == imageData.count)

        #expect(
            payload.format
                .uniformTypeIdentifier ==
                UTType.png.identifier
        )

        #expect(
            payload.format
                .filenameExtension ==
                "png"
        )

        #expect(
            payload.format.displayName ==
                "PNG"
        )

        #expect(
            payload.originalFilename ==
                "source-image.png"
        )

        #expect(!payload.wasConverted)

        #expect(
            payload.contentHash.count ==
                64
        )

        #expect(
            payload.contentHash ==
                payload.contentHash
                    .lowercased()
        )

        let fileURL =
            try await service.imageFileURL(
                for: payload
            )

        #expect(
            FileManager.default.fileExists(
                atPath: fileURL.path
            )
        )

        #expect(
            fileURL.lastPathComponent ==
                payload.storedFilename
        )
    }

    @Test
    func loadingStoredImageReturnsOriginalBytes()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let service =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let originalData =
            try makePNGData(
                width: 8,
                height: 6
            )

        let payload =
            try await service.storeImage(
                data: originalData
            )

        let loadedData =
            try await service.loadImageData(
                for: payload
            )

        #expect(
            loadedData ==
                originalData
        )
    }

    @Test
    func identicalImageBytesProduceSameDuplicateKey()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let service =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let imageData =
            try makePNGData(
                width: 5,
                height: 5
            )

        let firstPayload =
            try await service.storeImage(
                data: imageData
            )

        let secondPayload =
            try await service.storeImage(
                data: imageData
            )

        #expect(
            firstPayload.storageIdentifier !=
                secondPayload.storageIdentifier
        )

        #expect(
            firstPayload.contentHash ==
                secondPayload.contentHash
        )

        #expect(
            firstPayload.duplicateKey ==
                secondPayload.duplicateKey
        )
    }

    @Test
    func storingImageRecordsConversionFlag()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let service =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let payload =
            try await service.storeImage(
                data:
                    makePNGData(
                        width: 2,
                        height: 2
                    ),
                wasConverted: true
            )

        #expect(payload.wasConverted)
    }

    @Test
    func deletingImageRemovesManagedFileAndIsIdempotent()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let service =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let payload =
            try await service.storeImage(
                data:
                    makePNGData(
                        width: 3,
                        height: 3
                    )
            )

        let fileURL =
            try await service.imageFileURL(
                for: payload
            )

        try await service.deleteImage(
            for: payload
        )

        #expect(
            !FileManager.default.fileExists(
                atPath: fileURL.path
            )
        )

        try await service.deleteImage(
            for: payload
        )
    }

    @Test
    func emptyImageDataIsRejected()
        async
    {
        let service =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    makeTestDirectory()
            )

        do {
            _ = try await service.storeImage(
                data: Data()
            )

            Issue.record(
                "Expected empty image data to be rejected."
            )
        } catch let error
            as ClipboardImageStorageError
        {
            #expect(
                error == .emptyImageData
            )
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }
    }

    @Test
    func invalidImageDataIsRejected()
        async
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let service =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        do {
            _ = try await service.storeImage(
                data:
                    Data(
                        "Not an image".utf8
                    )
            )

            Issue.record(
                "Expected invalid image data to be rejected."
            )
        } catch let error
            as ClipboardImageStorageError
        {
            #expect(
                error == .invalidImageData
            )
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }
    }

    @Test
    func alteredStoredImageIsDetectedAsCorrupted()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let service =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let payload =
            try await service.storeImage(
                data:
                    makePNGData(
                        width: 6,
                        height: 4
                    )
            )

        let fileURL =
            try await service.imageFileURL(
                for: payload
            )

        try Data(
            "Corrupted image data".utf8
        )
        .write(
            to: fileURL,
            options: [.atomic]
        )

        do {
            _ = try await service.loadImageData(
                for: payload
            )

            Issue.record(
                "Expected corrupted image data to be rejected."
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
    }

    @Test
    func validationReflectsStoredFileAvailability()
        async throws
    {
        let testDirectory =
            makeTestDirectory()

        defer {
            removeTestDirectory(
                testDirectory
            )
        }

        let service =
            ClipboardImageStorageService(
                imagesDirectoryURL:
                    testDirectory
            )

        let payload =
            try await service.storeImage(
                data:
                    makePNGData(
                        width: 7,
                        height: 5
                    )
            )

        #expect(
            await service.validateStoredImage(
                for: payload
            )
        )

        try await service.deleteImage(
            for: payload
        )

        #expect(
            !(await service
                .validateStoredImage(
                    for: payload
                ))
        )
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
            let data =
                bitmap.representation(
                    using: .png,
                    properties: [:]
                )
        else {
            throw TestImageError
                .couldNotCreateImage
        }

        return data
    }

    private func makeTestDirectory() -> URL {
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "ClipboardImageStorageServiceTests-" +
                UUID().uuidString,
                isDirectory: true
            )
    }

    private func removeTestDirectory(
        _ directoryURL: URL
    ) {
        try? FileManager.default.removeItem(
            at: directoryURL
        )
    }
}

private enum TestImageError: Error {
    case couldNotCreateImage
}
