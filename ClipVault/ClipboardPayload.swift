//
//  ClipboardPayload.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

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

    var compatibilityText: String {
        searchableText
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
