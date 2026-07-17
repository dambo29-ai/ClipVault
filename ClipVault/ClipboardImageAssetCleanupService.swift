//
//  ClipboardImageAssetCleanupService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

import Foundation

@MainActor
enum ClipboardImageAssetCleanupService {
    static func unreferencedImagePayloads(
        previousItems: [ClipboardItem],
        remainingItems: [ClipboardItem]
    ) -> [ClipboardImagePayload] {
        let remainingStorageIdentifiers =
            Set(
                remainingItems.compactMap {
                    $0.imagePayload?
                        .storageIdentifier
                }
            )

        var returnedStorageIdentifiers:
            Set<UUID> = []

        return previousItems.compactMap {
            item in

            guard
                let imagePayload =
                    item.imagePayload
            else {
                return nil
            }

            let storageIdentifier =
                imagePayload
                    .storageIdentifier

            guard
                !remainingStorageIdentifiers
                    .contains(
                        storageIdentifier
                    )
            else {
                return nil
            }

            guard
                returnedStorageIdentifiers
                    .insert(
                        storageIdentifier
                    )
                    .inserted
            else {
                return nil
            }

            return imagePayload
        }
    }
}
