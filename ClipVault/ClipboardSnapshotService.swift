//
//  ClipboardSnapshotService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/13/26.
//

import AppKit
import Foundation

struct ClipboardSnapshot {
    struct Item {
        let representations: [
            NSPasteboard.PasteboardType: Data
        ]
    }

    let items: [Item]
}

@MainActor
enum ClipboardSnapshotService {
    static func capture(
        from pasteboard: NSPasteboard
    ) -> ClipboardSnapshot {
        let snapshotItems: [ClipboardSnapshot.Item] =
            pasteboard.pasteboardItems?.map {
                pasteboardItem in

                var representations: [
                    NSPasteboard.PasteboardType: Data
                ] = [:]

                for type in pasteboardItem.types {
                    guard let data =
                        pasteboardItem.data(
                            forType: type
                        ) else {
                        continue
                    }

                    representations[type] = data
                }

                return ClipboardSnapshot.Item(
                    representations: representations
                )
            } ?? []

        return ClipboardSnapshot(
            items: snapshotItems
        )
    }

    @discardableResult
    static func restore(
        _ snapshot: ClipboardSnapshot,
        to pasteboard: NSPasteboard
    ) -> Bool {
        let restoredItems =
            snapshot.items.compactMap {
                snapshotItem -> NSPasteboardItem? in

                let pasteboardItem = NSPasteboardItem()
                var restoredRepresentationCount = 0

                for (
                    type,
                    data
                ) in snapshotItem.representations {
                    if pasteboardItem.setData(
                        data,
                        forType: type
                    ) {
                        restoredRepresentationCount += 1
                    }
                }

                guard restoredRepresentationCount > 0 else {
                    return nil
                }

                return pasteboardItem
            }

        pasteboard.clearContents()

        guard !restoredItems.isEmpty else {
            return snapshot.items.isEmpty
        }

        guard restoredItems.count == snapshot.items.count else {
            return false
        }

        return pasteboard.writeObjects(
            restoredItems
        )
    }
}

