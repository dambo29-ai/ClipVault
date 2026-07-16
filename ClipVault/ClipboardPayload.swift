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

    var contentKind: ClipboardContentKind {
        switch self {
        case .text:
            return .text

        case .link:
            return .link
        }
    }

    var searchableText: String {
        switch self {
        case let .text(payload):
            return payload.text

        case let .link(payload):
            return payload.urlString
        }
    }
    
    var displayText: String {
        switch self {
        case let .text(payload):
            return payload.text

        case let .link(payload):
            return payload.urlString
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

    @discardableResult
    func write(
        to pasteboard: NSPasteboard
    ) -> Bool {
        pasteboard.clearContents()

        switch self {
        case let .text(payload):
            return pasteboard.setString(
                payload.text,
                forType: .string
            )

        case let .link(payload):
            return pasteboard.setString(
                payload.urlString,
                forType: .string
            )
        }
    }

    var compatibilityText: String {
        displayText
    }
    
    var duplicateKey: String {
        searchableText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
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
