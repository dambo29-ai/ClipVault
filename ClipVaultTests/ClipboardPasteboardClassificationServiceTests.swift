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
            case let .text(
                textPayload
            ) =
                content
        else {
            Issue.record(
                "Expected ordinary text."
            )

            return
        }

        #expect(
            textPayload.text ==
                "Ordinary clipboard text"
        )

        #expect(
            textPayload.rtfData ==
                nil
        )

        #expect(
            textPayload.htmlData ==
                nil
        )
    }
    
    @Test
    func richTextRepresentationsAreCaptured()
    {
        let pasteboard =
            makePasteboard()

        let rtfData =
            Data(
                "{\\rtf1\\ansi Rich text}"
                    .utf8
            )

        let htmlData =
            Data(
                "<p><strong>Rich text</strong></p>"
                    .utf8
            )

        let pasteboardItem =
            NSPasteboardItem()

        pasteboardItem
            .setString(
                "Rich text",
                forType:
                    .string
            )

        pasteboardItem
            .setData(
                rtfData,
                forType:
                    .rtf
            )

        pasteboardItem
            .setData(
                htmlData,
                forType:
                    .html
            )

        pasteboard
            .clearContents()

        pasteboard
            .writeObjects(
                [
                    pasteboardItem
                ]
            )

        let content =
            ClipboardPasteboardClassificationService
                .content(
                    from:
                        pasteboard
                )

        guard
            case let .text(
                textPayload
            ) =
                content
        else {
            Issue.record(
                "Expected a text payload."
            )

            return
        }

        #expect(
            textPayload.text ==
                "Rich text"
        )

        #expect(
            textPayload.rtfData ==
                rtfData
        )

        #expect(
            textPayload.htmlData ==
                htmlData
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
    func richSpreadsheetTextTakesPriorityOverRasterImage()
    {
        let pasteboard =
            makePasteboard()

        let imageData =
            Data(
                [1, 2, 3, 4]
            )

        let rtfData =
            Data(
                "{\\rtf1\\ansi Cell Value}"
                    .utf8
            )

        let htmlData =
            Data(
                "<table><tr><td>Cell Value</td></tr></table>"
                    .utf8
            )

        let pasteboardItem =
            NSPasteboardItem()

        pasteboardItem
            .setString(
                "Cell Value",
                forType:
                    .string
            )

        pasteboardItem
            .setData(
                rtfData,
                forType:
                    .rtf
            )

        pasteboardItem
            .setData(
                htmlData,
                forType:
                    .html
            )

        pasteboardItem
            .setData(
                imageData,
                forType:
                    .png
            )

        pasteboard
            .clearContents()

        pasteboard
            .writeObjects(
                [
                    pasteboardItem
                ]
            )

        let content =
            ClipboardPasteboardClassificationService
                .content(
                    from:
                        pasteboard
                )

        guard
            case let .text(
                textPayload
            ) =
                content
        else {
            Issue.record(
                "Expected editable spreadsheet text to take priority over the rendered image."
            )

            return
        }

        #expect(
            textPayload.text ==
                "Cell Value"
        )

        #expect(
            textPayload.rtfData ==
                rtfData
        )

        #expect(
            textPayload.htmlData ==
                htmlData
        )
    }

    @Test
    func tabularPlainTextTakesPriorityOverRasterImage()
    {
        let pasteboard =
            makePasteboard()

        let imageData =
            Data(
                [5, 6, 7, 8]
            )

        let tabularText =
            """
            A1\tB1
            A2\tB2
            """

        let pasteboardItem =
            NSPasteboardItem()

        pasteboardItem
            .setString(
                tabularText,
                forType:
                    .string
            )

        pasteboardItem
            .setData(
                imageData,
                forType:
                    .png
            )

        pasteboard
            .clearContents()

        pasteboard
            .writeObjects(
                [
                    pasteboardItem
                ]
            )

        let content =
            ClipboardPasteboardClassificationService
                .content(
                    from:
                        pasteboard
                )

        guard
            case let .text(
                textPayload
            ) =
                content
        else {
            Issue.record(
                "Expected tabular text to take priority over the rendered image."
            )

            return
        }

        #expect(
            textPayload.text ==
                tabularText
        )
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
