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
    let text: String
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

    var contentKind: ClipboardContentKind {
        switch self {
        case .text:
            return .text

        case .link:
            return .link

        case .image:
            return .image
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

    @discardableResult
    func write(
        to pasteboard: NSPasteboard
    ) -> Bool {
        switch self {
        case let .text(payload):
            pasteboard.clearContents()

            return pasteboard.setString(
                payload.text,
                forType: .string
            )

        case let .link(payload):
            pasteboard.clearContents()

            return pasteboard.setString(
                payload.urlString,
                forType: .string
            )

        case .image:
            /*
             Image data is stored in the managed Images
             directory rather than inside this payload.

             Pasteboard restoration will be connected after
             ClipboardImageStorageService is integrated into
             ClipboardStore.
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
