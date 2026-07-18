//
//  ClipboardPasteboardClassificationServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardPasteboardClassificationServiceTests {
    @Test
    func fileURLTakesPriorityOverFilenameText() {
        let pasteboard =
            makePasteboard()

        let fileURL =
            URL(
                fileURLWithPath:
                    "/tmp/family-photo.png"
            )

        let pasteboardItem =
            NSPasteboardItem()

        pasteboardItem.setString(
            fileURL.absoluteString,
            forType: .fileURL
        )

        pasteboardItem.setString(
            "family-photo.png",
            forType: .string
        )

        pasteboard.clearContents()

        pasteboard.writeObjects([
            pasteboardItem
        ])

        let content =
            ClipboardPasteboardClassificationService
                .content(
                    from: pasteboard
                )

        guard
            case let .fileURLs(fileURLs) =
                content
        else {
            Issue.record(
                "Expected the file URL representation to take priority."
            )
            return
        }

        #expect(
            fileURLs == [
                fileURL
            ]
        )
    }

    @Test
    func multipleFileURLsArePreserved() {
        let pasteboard =
            makePasteboard()

        let fileURLs = [
            URL(
                fileURLWithPath:
                    "/tmp/first.png"
            ),
            URL(
                fileURLWithPath:
                    "/tmp/second.jpg"
            ),
            URL(
                fileURLWithPath:
                    "/tmp/third.tiff"
            )
        ]

        let pasteboardItems =
            fileURLs.map {
                fileURL in

                let item =
                    NSPasteboardItem()

                item.setString(
                    fileURL.absoluteString,
                    forType: .fileURL
                )

                return item
            }

        pasteboard.clearContents()

        pasteboard.writeObjects(
            pasteboardItems
        )

        let content =
            ClipboardPasteboardClassificationService
                .content(
                    from: pasteboard
                )

        guard
            case let .fileURLs(
                classifiedURLs
            ) = content
        else {
            Issue.record(
                "Expected multiple file URLs."
            )
            return
        }

        #expect(
            classifiedURLs ==
                fileURLs
        )
    }

    @Test
    func plainTextIsUsedWhenNoFileURLExists() {
        let pasteboard =
            makePasteboard()

        pasteboard.clearContents()

        pasteboard.setString(
            "Ordinary clipboard text",
            forType: .string
        )

        let content =
            ClipboardPasteboardClassificationService
                .content(
                    from: pasteboard
                )

        guard
            case let .text(text) =
                content
        else {
            Issue.record(
                "Expected ordinary text."
            )
            return
        }

        #expect(
            text ==
                "Ordinary clipboard text"
        )
    }

    @Test
    func emptyPasteboardProducesNoContent() {
        let pasteboard =
            makePasteboard()

        pasteboard.clearContents()

        let content =
            ClipboardPasteboardClassificationService
                .content(
                    from: pasteboard
                )

        #expect(content == nil)
    }
    
    @Test
    func rasterImageTakesPriorityOverText() {
        let pasteboard =
            makePasteboard()

        let imageData =
            Data(
                [1, 2, 3, 4]
            )

        pasteboard.clearContents()

        pasteboard.setData(
            imageData,
            forType:
                .png
        )

        pasteboard.setString(
            "https://example.com/image.png",
            forType:
                .string
        )

        let content =
            ClipboardPasteboardClassificationService
                .content(
                    from:
                        pasteboard
                )

        guard
            case let .rasterImage(
                classifiedData
            ) = content
        else {
            Issue.record(
                "Expected raster image data to take priority over text."
            )

            return
        }

        #expect(
            classifiedData ==
                imageData
        )
    }

    @Test
    func fileURLTakesPriorityOverRasterImage() {
        let pasteboard =
            makePasteboard()

        let fileURL =
            URL(
                fileURLWithPath:
                    "/tmp/photo.png"
            )

        let pasteboardItem =
            NSPasteboardItem()

        pasteboardItem.setString(
            fileURL.absoluteString,
            forType:
                .fileURL
        )

        pasteboardItem.setData(
            Data(
                [5, 6, 7, 8]
            ),
            forType:
                .png
        )

        pasteboard.clearContents()

        pasteboard.writeObjects([
            pasteboardItem
        ])

        let content =
            ClipboardPasteboardClassificationService
                .content(
                    from:
                        pasteboard
                )

        guard
            case let .fileURLs(
                fileURLs
            ) = content
        else {
            Issue.record(
                "Expected file URLs to take priority over raster image data."
            )

            return
        }

        #expect(
            fileURLs ==
                [
                    fileURL
                ]
        )
    }

    @Test
    func tiffImageIsRecognized() {
        let pasteboard =
            makePasteboard()

        let imageData =
            Data(
                [9, 10, 11, 12]
            )

        pasteboard.clearContents()

        pasteboard.setData(
            imageData,
            forType:
                .tiff
        )

        let content =
            ClipboardPasteboardClassificationService
                .content(
                    from:
                        pasteboard
                )

        guard
            case let .rasterImage(
                classifiedData
            ) = content
        else {
            Issue.record(
                "Expected TIFF image data."
            )

            return
        }

        #expect(
            classifiedData ==
                imageData
        )
    }

    private func makePasteboard()
        -> NSPasteboard
    {
        NSPasteboard(
            name:
                NSPasteboard.Name(
                    "ClipboardPasteboardClassificationServiceTests-" +
                    UUID().uuidString
                )
        )
    }
}
