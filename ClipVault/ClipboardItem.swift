//
//  ClipboardItem.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/8/26.
//

import Foundation

enum ClipboardItemKind: String, Codable {
    case normal
    case sensitiveSkipped
}

enum ClipboardItemOrigin: String, Codable {
    case captured
    case restored
}

enum ClipboardContentKind:
    String,
    Codable,
    Equatable,
    Sendable
{
    case text
    case link
    case image
    case files
}

struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    let text: String
    let createdAt: Date
    let kind: ClipboardItemKind
    let sourceAppName: String?
    let sourceBundleIdentifier: String?
    let origin: ClipboardItemOrigin
    let contentKind: ClipboardContentKind
    let isPinned: Bool
    let pinnedAt: Date?
    
    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        kind: ClipboardItemKind = .normal,
        sourceAppName: String? = nil,
        sourceBundleIdentifier: String? = nil,
        origin: ClipboardItemOrigin = .captured,
        contentKind: ClipboardContentKind? = nil,
        isPinned: Bool = false,
        pinnedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.kind = kind
        self.sourceAppName = sourceAppName
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.origin = origin
        self.contentKind =
            contentKind ??
            ClipboardItem.inferredContentKind(
                text: text,
                itemKind: kind
            )
        self.isPinned = isPinned
        self.pinnedAt = isPinned ? pinnedAt : nil
    }

    func pinnedCopy(
        pinnedAt: Date = Date()
    ) -> ClipboardItem {
        guard kind == .normal else {
            return self
        }

        return ClipboardItem(
            id: id,
            text: text,
            createdAt: createdAt,
            kind: kind,
            sourceAppName: sourceAppName,
            sourceBundleIdentifier:
                sourceBundleIdentifier,
            origin: origin,
            contentKind: contentKind,
            isPinned: true,
            pinnedAt: pinnedAt
        )
    }

    func unpinnedCopy() -> ClipboardItem {
        ClipboardItem(
            id: id,
            text: text,
            createdAt: createdAt,
            kind: kind,
            sourceAppName: sourceAppName,
            sourceBundleIdentifier:
                sourceBundleIdentifier,
            origin: origin,
            contentKind: contentKind,
            isPinned: false,
            pinnedAt: nil
        )
    }
    
    func restoredCopy() -> ClipboardItem {
        ClipboardItem(
            id: id,
            text: text,
            createdAt: createdAt,
            kind: kind,
            sourceAppName: sourceAppName,
            sourceBundleIdentifier: sourceBundleIdentifier,
            origin: .restored,
            contentKind: contentKind,
            isPinned: isPinned,
            pinnedAt: pinnedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case createdAt
        case kind
        case sourceAppName
        case sourceBundleIdentifier
        case origin
        case contentKind
        case isPinned
        case pinnedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        id = try container.decode(
            UUID.self,
            forKey: .id
        )

        text = try container.decode(
            String.self,
            forKey: .text
        )

        createdAt = try container.decode(
            Date.self,
            forKey: .createdAt
        )

        kind = try container.decode(
            ClipboardItemKind.self,
            forKey: .kind
        )

        sourceAppName = try container.decodeIfPresent(
            String.self,
            forKey: .sourceAppName
        )

        sourceBundleIdentifier = try container.decodeIfPresent(
            String.self,
            forKey: .sourceBundleIdentifier
        )

        origin = try container.decodeIfPresent(
            ClipboardItemOrigin.self,
            forKey: .origin
        ) ?? .captured

        contentKind =
            try container.decodeIfPresent(
                ClipboardContentKind.self,
                forKey: .contentKind
            ) ??
            ClipboardItem.inferredContentKind(
                text: text,
                itemKind: kind
            )

        isPinned = try container.decodeIfPresent(
            Bool.self,
            forKey: .isPinned
        ) ?? false

        if isPinned {
            pinnedAt = try container.decodeIfPresent(
                Date.self,
                forKey: .pinnedAt
            )
        } else {
            pinnedAt = nil
        }
    }

    private static func inferredContentKind(
        text: String,
        itemKind: ClipboardItemKind
    ) -> ClipboardContentKind {
        guard itemKind == .normal else {
            return .text
        }

        return ClipboardLinkClassificationService.isLink(
            text
        )
            ? .link
            : .text
    }
}
