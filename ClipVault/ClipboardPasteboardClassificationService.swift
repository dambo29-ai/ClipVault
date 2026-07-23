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
        from pasteboard: NSPasteboard
    ) -> ClipboardChangeContent? {
        let fileURLs =
            (
                pasteboard.readObjects(
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
            } ?? []

        if !fileURLs.isEmpty {
            return .fileURLs(
                fileURLs
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

        guard
            let text =
                pasteboard.string(
                    forType:
                        .string
                )
        else {
            return nil
        }

        return .text(
            ClipboardTextPayload(
                text:
                    text,
                rtfData:
                    pasteboard.data(
                        forType:
                            .rtf
                    ),
                htmlData:
                    pasteboard.data(
                        forType:
                            .html
                    )
            )
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
