//
//  ClipboardSnapshotServiceTests.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/13/26.
//

import AppKit
import Testing
@testable import ClipVault

@MainActor
struct ClipboardSnapshotServiceTests {
    @Test
    func restoresPlainTextClipboardItem() throws {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()
        pasteboard.setString(
            "Original clipboard text",
            forType: .string
        )

        let snapshot =
            ClipboardSnapshotService.capture(
                from: pasteboard
            )

        pasteboard.clearContents()
        pasteboard.setString(
            "Temporary copied text",
            forType: .string
        )

        let restorationSucceeded =
            ClipboardSnapshotService.restore(
                snapshot,
                to: pasteboard
            )

        #expect(restorationSucceeded)
        #expect(
            pasteboard.string(forType: .string) ==
                "Original clipboard text"
        )
    }

    @Test
    func restoresMultipleRepresentations() throws {
        let pasteboard = makePasteboard()
        let originalItem = NSPasteboardItem()

        let plainText =
            "Original formatted text"

        let html =
            """
            <p><strong>Original formatted text</strong></p>
            """

        try #require(
            originalItem.setString(
                plainText,
                forType: .string
            )
        )

        try #require(
            originalItem.setString(
                html,
                forType: .html
            )
        )

        pasteboard.clearContents()

        try #require(
            pasteboard.writeObjects([
                originalItem
            ])
        )

        let snapshot =
            ClipboardSnapshotService.capture(
                from: pasteboard
            )

        pasteboard.clearContents()
        pasteboard.setString(
            "Temporary text",
            forType: .string
        )

        let restorationSucceeded =
            ClipboardSnapshotService.restore(
                snapshot,
                to: pasteboard
            )

        #expect(restorationSucceeded)

        let restoredItem =
            try #require(
                pasteboard.pasteboardItems?.first
            )

        #expect(
            restoredItem.string(forType: .string) ==
                plainText
        )

        #expect(
            restoredItem.string(forType: .html) ==
                html
        )
    }

    @Test
    func restoresMultipleClipboardItemsInOrder() throws {
        let pasteboard = makePasteboard()

        let firstItem = NSPasteboardItem()
        let secondItem = NSPasteboardItem()

        try #require(
            firstItem.setString(
                "First item",
                forType: .string
            )
        )

        try #require(
            secondItem.setString(
                "Second item",
                forType: .string
            )
        )

        pasteboard.clearContents()

        try #require(
            pasteboard.writeObjects([
                firstItem,
                secondItem
            ])
        )

        let snapshot =
            ClipboardSnapshotService.capture(
                from: pasteboard
            )

        pasteboard.clearContents()
        pasteboard.setString(
            "Temporary item",
            forType: .string
        )

        let restorationSucceeded =
            ClipboardSnapshotService.restore(
                snapshot,
                to: pasteboard
            )

        #expect(restorationSucceeded)

        let restoredItems =
            try #require(
                pasteboard.pasteboardItems
            )

        #expect(restoredItems.count == 2)

        #expect(
            restoredItems[0].string(
                forType: .string
            ) == "First item"
        )

        #expect(
            restoredItems[1].string(
                forType: .string
            ) == "Second item"
        )
    }

    @Test
    func restoresAnEmptyClipboard() {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()

        let snapshot =
            ClipboardSnapshotService.capture(
                from: pasteboard
            )

        pasteboard.setString(
            "Temporary item",
            forType: .string
        )

        let restorationSucceeded =
            ClipboardSnapshotService.restore(
                snapshot,
                to: pasteboard
            )

        #expect(restorationSucceeded)
        #expect(pasteboard.pasteboardItems?.isEmpty != false)
        #expect(pasteboard.string(forType: .string) == nil)
    }

    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(
            name: NSPasteboard.Name(
                "ClipboardSnapshotServiceTests-\(UUID().uuidString)"
            )
        )
    }
}

