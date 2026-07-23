//
//  ClipboardPasteboardClassificationService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum ClipboardChangeContent {
    case fileURLs(
        [URL]
    )

    case rasterImage(
        Data
    )

    case text(
        ClipboardTextPayload
    )
}

@MainActor
enum ClipboardPasteboardClassificationService {
    static func content(
        from pasteboard:
            NSPasteboard
    ) -> ClipboardChangeContent? {
        let fileURLs =
            (
                pasteboard
                    .readObjects(
                        forClasses: [
                            NSURL.self
                        ],
                        options: [
                            .urlReadingFileURLsOnly:
                                true
                        ]
                    ) as? [NSURL]
            )?
            .map {
                $0 as URL
            } ??
            []

        if !fileURLs.isEmpty {
            return .fileURLs(
                fileURLs
            )
        }

        let textPayload =
            textPayload(
                from:
                    pasteboard
            )

        /*
         Spreadsheet applications commonly place both
         editable text/table representations and a rendered
         image on the pasteboard. Prefer the editable data
         when rich or tabular text is present.
         */
        if let textPayload,
           isRichOrTabularText(
                textPayload
           )
        {
            return .text(
                textPayload
            )
        }

        if let imageData =
            rasterImageData(
                from:
                    pasteboard
            )
        {
            return .rasterImage(
                imageData
            )
        }

        if let textPayload {
            return .text(
                textPayload
            )
        }

        return nil
    }
    
    private static func textPayload(
        from pasteboard:
            NSPasteboard
    ) -> ClipboardTextPayload? {
        guard
            let text =
                pasteboard
                    .string(
                        forType:
                            .string
                    ),
            !text.isEmpty
        else {
            return nil
        }

        return ClipboardTextPayload(
            text:
                text,
            rtfData:
                pasteboard
                    .data(
                        forType:
                            .rtf
                    ),
            htmlData:
                pasteboard
                    .data(
                        forType:
                            .html
                    )
        )
    }

    private static func isRichOrTabularText(
        _ payload:
            ClipboardTextPayload
    ) -> Bool {
        if payload.rtfData !=
            nil ||
            payload.htmlData !=
            nil
        {
            return true
        }

        return payload.text
            .contains(
                "\t"
            ) ||
            payload.text
                .contains(
                    "\n"
                ) ||
            payload.text
                .contains(
                    "\r"
                )
    }

    private static func rasterImageData(
        from pasteboard:
            NSPasteboard
    ) -> Data? {
        let preferredTypes:
            [NSPasteboard.PasteboardType] =
                [
                    .png,
                    .tiff
                ]

        for pasteboardType in
            preferredTypes
        {
            if let data =
                pasteboard.data(
                    forType:
                        pasteboardType
                ),
               !data.isEmpty
            {
                return data
            }
        }

        for pasteboardType in
            pasteboard.types ?? []
        {
            guard
                pasteboardType !=
                    .fileURL,
                pasteboardType !=
                    .pdf,
                let uniformType =
                    UTType(
                        pasteboardType
                            .rawValue
                    ),
                uniformType.conforms(
                    to:
                        .image
                ),
                let data =
                    pasteboard.data(
                        forType:
                            pasteboardType
                    ),
                !data.isEmpty
            else {
                continue
            }

            return data
        }

        return nil
    }
}
