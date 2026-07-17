//
//  ClipboardPasteboardClassificationService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import Foundation

enum ClipboardChangeContent {
    case fileURLs([URL])
    case text(String)
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

        guard
            let text =
                pasteboard.string(
                    forType: .string
                )
        else {
            return nil
        }

        return .text(text)
    }
}
