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
    let urlString: String
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
            return payload.urlString

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
            return payload.urlString

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
            pasteboard.clearContents()

            return pasteboard.setString(
                payload.urlString,
                forType: .string
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

        if ClipboardLinkClassificationService.isLink(
            text
        ) {
            return .link(
                ClipboardLinkPayload(
                    urlString: text
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
