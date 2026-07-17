//
//  ClipboardImageAssetCleanupServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/16/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardImageAssetCleanupServiceTests {
    @Test
    func removedImageProducesCleanupPayload() {
        let imagePayload =
            makeImagePayload()

        let imageItem =
            makeImageItem(
                payload:
                    imagePayload
            )

        let result =
            ClipboardImageAssetCleanupService
                .unreferencedImagePayloads(
                    previousItems: [
                        imageItem
                    ],
                    remainingItems: []
                )

        #expect(
            result == [
                imagePayload
            ]
        )
    }

    @Test
    func retainedImageDoesNotProduceCleanupPayload() {
        let imagePayload =
            makeImagePayload()

        let imageItem =
            makeImageItem(
                payload:
                    imagePayload
            )

        let result =
            ClipboardImageAssetCleanupService
                .unreferencedImagePayloads(
                    previousItems: [
                        imageItem
                    ],
                    remainingItems: [
                        imageItem
                    ]
                )

        #expect(result.isEmpty)
    }

    @Test
    func removingTextAndLinkItemsDoesNotProduceImageCleanup() {
        let previousItems = [
            ClipboardItem(
                text:
                    "Ordinary clipboard text"
            ),
            ClipboardItem(
                text:
                    "https://example.com",
                contentKind: .link
            )
        ]

        let result =
            ClipboardImageAssetCleanupService
                .unreferencedImagePayloads(
                    previousItems:
                        previousItems,
                    remainingItems: []
                )

        #expect(result.isEmpty)
    }

    @Test
    func sharedImageAssetIsPreservedWhileStillReferenced() {
        let imagePayload =
            makeImagePayload()

        let firstItem =
            makeImageItem(
                id: UUID(),
                payload:
                    imagePayload
            )

        let secondItem =
            makeImageItem(
                id: UUID(),
                payload:
                    imagePayload
            )

        let result =
            ClipboardImageAssetCleanupService
                .unreferencedImagePayloads(
                    previousItems: [
                        firstItem,
                        secondItem
                    ],
                    remainingItems: [
                        secondItem
                    ]
                )

        #expect(result.isEmpty)
    }

    @Test
    func sharedImageAssetIsReturnedOnlyOnceWhenLastReferencesDisappear() {
        let imagePayload =
            makeImagePayload()

        let firstItem =
            makeImageItem(
                id: UUID(),
                payload:
                    imagePayload
            )

        let secondItem =
            makeImageItem(
                id: UUID(),
                payload:
                    imagePayload
            )

        let result =
            ClipboardImageAssetCleanupService
                .unreferencedImagePayloads(
                    previousItems: [
                        firstItem,
                        secondItem
                    ],
                    remainingItems: []
                )

        #expect(
            result == [
                imagePayload
            ]
        )
    }

    @Test
    func onlyRemovedImageAssetsAreReturned() {
        let retainedPayload =
            makeImagePayload(
                storageIdentifier:
                    UUID(
                        uuidString:
                            "11111111-1111-1111-1111-111111111111"
                    )!
            )

        let removedPayload =
            makeImagePayload(
                storageIdentifier:
                    UUID(
                        uuidString:
                            "22222222-2222-2222-2222-222222222222"
                    )!
            )

        let retainedItem =
            makeImageItem(
                payload:
                    retainedPayload
            )

        let removedItem =
            makeImageItem(
                payload:
                    removedPayload
            )

        let result =
            ClipboardImageAssetCleanupService
                .unreferencedImagePayloads(
                    previousItems: [
                        retainedItem,
                        removedItem
                    ],
                    remainingItems: [
                        retainedItem
                    ]
                )

        #expect(
            result == [
                removedPayload
            ]
        )
    }

    @Test
    func replacingItemMetadataWithoutChangingAssetDoesNotDeleteImage() {
        let imagePayload =
            makeImagePayload()

        let originalItem =
            makeImageItem(
                id: UUID(),
                payload:
                    imagePayload,
                isPinned: false
            )

        let updatedItem =
            makeImageItem(
                id: originalItem.id,
                payload:
                    imagePayload,
                isPinned: true
            )

        let result =
            ClipboardImageAssetCleanupService
                .unreferencedImagePayloads(
                    previousItems: [
                        originalItem
                    ],
                    remainingItems: [
                        updatedItem
                    ]
                )

        #expect(result.isEmpty)
    }

    private func makeImageItem(
        id: UUID = UUID(),
        payload:
            ClipboardImagePayload,
        isPinned: Bool = false
    ) -> ClipboardItem {
        ClipboardItem(
            id: id,
            payload:
                .image(payload),
            isPinned:
                isPinned,
            pinnedAt:
                isPinned
                    ? Date()
                    : nil
        )
    }

    private func makeImagePayload(
        storageIdentifier:
            UUID = UUID()
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
            pixelWidth: 1440,
            pixelHeight: 900,
            byteCount: 842_000,
            contentHash:
                storageIdentifier
                    .uuidString
                    .lowercased(),
            originalFilename:
                "test-image.png",
            wasConverted: false
        )
    }
}
