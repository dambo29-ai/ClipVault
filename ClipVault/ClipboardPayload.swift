//
//  ClipboardPayload.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import Foundation

struct ClipboardTextPayload:
    Codable,
    Equatable,
    Sendable
{
    let text:
        String

    let rtfData:
        Data?

    let htmlData:
        Data?

    init(
        text:
            String,
        rtfData:
            Data? =
                nil,
        htmlData:
            Data? =
                nil
    ) {
        self.text =
            text

        self.rtfData =
            rtfData

        self.htmlData =
            htmlData
    }

    @discardableResult
    func write(
        to pasteboard:
            NSPasteboard
    ) -> Bool {
        let pasteboardItem =
            NSPasteboardItem()

        pasteboardItem
            .setString(
                text,
                forType:
                    .string
            )

        if let rtfData,
           !rtfData.isEmpty
        {
            pasteboardItem
                .setData(
                    rtfData,
                    forType:
                        .rtf
                )
        }

        if let htmlData,
           !htmlData.isEmpty
        {
            pasteboardItem
                .setData(
                    htmlData,
                    forType:
                        .html
                )
        }

        pasteboard
            .clearContents()

        return pasteboard
            .writeObjects(
                [
                    pasteboardItem
                ]
            )
    }
}

struct ClipboardLinkPayload:
    Codable,
    Equatable,
    Sendable
{
    /*
     The normalized HTTP or HTTPS URL used for opening
     the link and loading Link Presentation metadata.
     */
    let urlString:
        String

    /*
     The exact text originally copied by the user.
     Older saved payloads do not contain this field, so
     decoding falls back to urlString.
     */
    let displayText:
        String

    init(
        urlString:
            String,
        displayText:
            String? =
                nil
    ) {
        self.urlString =
            urlString

        self.displayText =
            displayText ??
            urlString
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case urlString
        case displayText
    }

    init(
        from decoder:
            Decoder
    ) throws {
        let container =
            try decoder
                .container(
                    keyedBy:
                        CodingKeys.self
                )

        let decodedURLString =
            try container
                .decode(
                    String.self,
                    forKey:
                        .urlString
                )

        urlString =
            decodedURLString

        displayText =
            try container
                .decodeIfPresent(
                    String.self,
                    forKey:
                        .displayText
                ) ??
            decodedURLString
    }

    func encode(
        to encoder:
            Encoder
    ) throws {
        var container =
            encoder
                .container(
                    keyedBy:
                        CodingKeys.self
                )

        try container
            .encode(
                urlString,
                forKey:
                    .urlString
            )

        try container
            .encode(
                displayText,
                forKey:
                    .displayText
            )
    }
}

enum ClipboardPayload:
    Codable,
    Equatable,
    Sendable
{
    case text(ClipboardTextPayload)
    case link(ClipboardLinkPayload)
    case image(ClipboardImagePayload)
    case files(ClipboardFilesPayload)

    var contentKind: ClipboardContentKind {
        switch self {
        case .text:
            return .text

        case .link:
            return .link

        case .image:
            return .image

        case .files:
            return .files
        }
    }

    var searchableText: String {
        switch self {
        case let .text(payload):
            return payload.text

        case let .link(payload):
            if payload.displayText ==
                payload.urlString
            {
                return payload.urlString
            }

            return [
                payload.displayText,
                payload.urlString
            ]
            .joined(
                separator:
                    "\n"
            )

        case let .image(payload):
            return payload.searchableText

        case let .files(payload):
            return payload.searchableText
        }
    }

    var displayText: String {
        switch self {
        case let .text(payload):
            return payload.text

        case let .link(payload):
            return payload.displayText

        case let .image(payload):
            return payload.displayTitle

        case let .files(payload):
            return payload.displayTitle
        }
    }

    var linkURL: URL? {
        guard
            case let .link(payload) = self
        else {
            return nil
        }

        let trimmedURLString =
            payload.urlString.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmedURLString.isEmpty else {
            return nil
        }

        return URL(
            string: trimmedURLString
        )
    }

    var imagePayload: ClipboardImagePayload? {
        guard
            case let .image(payload) = self
        else {
            return nil
        }

        return payload
    }
    
    var filesPayload: ClipboardFilesPayload? {
        guard
            case let .files(payload) = self
        else {
            return nil
        }

        return payload
    }

    @discardableResult
    func write(
        to pasteboard: NSPasteboard
    ) -> Bool {
        switch self {
        case let .text(payload):
            return payload
                .write(
                    to:
                        pasteboard
                )

        case let .link(payload):
            pasteboard
                .clearContents()

            return pasteboard
                .setString(
                    payload.displayText,
                    forType:
                        .string
                )

        case .image, .files:
            /*
             Image data and persistent File access are handled
             by dedicated services in ClipboardStore rather
             than directly by this lightweight payload.
             */
            return false
        }
    }

    var compatibilityText: String {
        displayText
    }

    var duplicateKey: String {
        switch self {
        case .text, .link:
            return searchableText
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        case let .image(payload):
            return payload.duplicateKey

        case let .files(payload):
            return payload.duplicateKey
        }
    }

    static func inferred(
        from text: String,
        itemKind: ClipboardItemKind
    ) -> ClipboardPayload {
        guard itemKind == .normal else {
            return .text(
                ClipboardTextPayload(
                    text: text
                )
            )
        }

        if let normalizedURLString =
            ClipboardLinkClassificationService
                .normalizedURLString(
                    for:
                        text
                )
        {
            return .link(
                ClipboardLinkPayload(
                    urlString:
                        normalizedURLString,
                    displayText:
                        text
                )
            )
        }

        return .text(
            ClipboardTextPayload(
                text: text
            )
        )
    }
}
