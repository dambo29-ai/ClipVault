//
//  ClipboardImagePayloadTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/16/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardImagePayloadTests {
    @Test
    func payloadProvidesImageRowMetadata() {
        let payload =
            makePayload(
                pixelWidth: 1440,
                pixelHeight: 900,
                byteCount: 842_000
            )

        #expect(
            payload.displayTitle ==
                "Copied Image"
        )

        #expect(
            payload.dimensionsText ==
                "1440 × 900"
        )
        
        #expect(
            !payload.byteCountText.isEmpty
        )

        #expect(
            payload.rowMetadataText.contains(
                "1440 × 900"
            )
        )

        #expect(
            payload.rowMetadataText.contains(
                "PNG"
            )
        )

        #expect(
            payload.rowMetadataText.contains(
                payload.byteCountText
            )
        )

        #expect(
            payload.searchableText.contains(
                "Copied Image"
            )
        )

        #expect(
            payload.searchableText.contains(
                "1440 × 900"
            )
        )

        #expect(
            payload.searchableText.contains(
                "PNG"
            )
        )
    }

    @Test
    func payloadCreatesManagedStorageFilename() {
        let storageIdentifier =
            UUID(
                uuidString:
                    "B10C1331-D322-42C6-9254-B488A5262900"
            )!

        let payload =
            makePayload(
                storageIdentifier:
                    storageIdentifier
            )

        #expect(
            payload.storedFilename ==
                "B10C1331-D322-42C6-9254-B488A5262900.png"
        )
    }

    @Test
    func formatNormalizesFilenameExtension() {
        let format =
            ClipboardImageFormat(
                uniformTypeIdentifier:
                    "public.png",
                filenameExtension:
                    ".PNG",
                displayName:
                    "PNG"
            )

        #expect(
            format.filenameExtension ==
                "png"
        )
    }

    @Test
    func payloadNormalizesContentHash() {
        let payload =
            makePayload(
                contentHash:
                    "  ABCDEF123456  "
            )

        #expect(
            payload.contentHash ==
                "abcdef123456"
        )

        #expect(
            payload.duplicateKey ==
                "image:abcdef123456"
        )
    }

    @Test
    func payloadPreservesOriginalFilename() {
        let payload =
            makePayload(
                originalFilename:
                    "  family-photo.tiff  "
            )

        #expect(
            payload.originalFilename ==
                "family-photo.tiff"
        )

        #expect(
            payload.searchableText.contains(
                "family-photo.tiff"
            )
        )
    }

    @Test
    func blankOriginalFilenameBecomesNil() {
        let payload =
            makePayload(
                originalFilename:
                    "   "
            )

        #expect(
            payload.originalFilename == nil
        )
    }

    @Test
    func negativeNumericMetadataIsClampedToZero() {
        let payload =
            makePayload(
                pixelWidth: -100,
                pixelHeight: -200,
                byteCount: -300
            )

        #expect(payload.pixelWidth == 0)
        #expect(payload.pixelHeight == 0)
        #expect(payload.byteCount == 0)

        #expect(
            payload.dimensionsText ==
                "0 × 0"
        )
    }

    @Test
    func payloadRecordsWhetherImageWasConverted() {
        let preservedPayload =
            makePayload(
                wasConverted: false
            )

        let convertedPayload =
            makePayload(
                wasConverted: true
            )

        #expect(
            !preservedPayload.wasConverted
        )

        #expect(
            convertedPayload.wasConverted
        )
    }

    @Test
    func payloadRoundTripPreservesMetadata() throws {
        let originalPayload =
            makePayload(
                originalFilename:
                    "source-image.tiff",
                wasConverted:
                    true
            )

        let encodedData =
            try JSONEncoder().encode(
                originalPayload
            )

        let decodedPayload =
            try JSONDecoder().decode(
                ClipboardImagePayload.self,
                from: encodedData
            )

        #expect(
            decodedPayload ==
                originalPayload
        )
    }

    private func makePayload(
        storageIdentifier:
            UUID = UUID(),
        pixelWidth: Int = 1440,
        pixelHeight: Int = 900,
        byteCount: Int = 842_000,
        contentHash:
            String = "abcdef123456",
        originalFilename:
            String? = nil,
        wasConverted:
            Bool = false
    ) -> ClipboardImagePayload {
        ClipboardImagePayload(
            storageIdentifier:
                storageIdentifier,
            format:
                ClipboardImageFormat(
                    uniformTypeIdentifier:
                        "public.png",
                    filenameExtension:
                        "png",
                    displayName:
                        "PNG"
                ),
            pixelWidth:
                pixelWidth,
            pixelHeight:
                pixelHeight,
            byteCount:
                byteCount,
            contentHash:
                contentHash,
            originalFilename:
                originalFilename,
            wasConverted:
                wasConverted
        )
    }
}
