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
    let payload: ClipboardPayload
    let createdAt: Date
    let kind: ClipboardItemKind
    let sourceAppName: String?
    let sourceBundleIdentifier: String?
    let origin: ClipboardItemOrigin
    let isPinned: Bool
    let pinnedAt: Date?
    let customTitle: String?

    var text: String {
        payload.compatibilityText
    }
    
    var displayText: String {
        customTitle ??
            payload.displayText
    }

    var automaticDisplayText: String {
        payload.displayText
    }

    var hasCustomTitle: Bool {
        customTitle != nil
    }

    var linkURL: URL? {
        payload.linkURL
    }
    
    var imagePayload: ClipboardImagePayload? {
        payload.imagePayload
    }

    var filesPayload: ClipboardFilesPayload? {
        payload.filesPayload
    }

    var searchableText: String {
        guard let customTitle else {
            return payload.searchableText
        }

        return """
        \(customTitle)
        \(payload.searchableText)
        """
    }
    
    var duplicateKey: String {
        payload.duplicateKey
    }

    var contentKind: ClipboardContentKind {
        payload.contentKind
    }

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
        pinnedAt: Date? = nil,
        customTitle: String? = nil
    ) {
        self.init(
            id: id,
            payload:
                ClipboardItem.payload(
                    from: text,
                    itemKind: kind,
                    explicitContentKind: contentKind
                ),
            createdAt: createdAt,
            kind: kind,
            sourceAppName: sourceAppName,
            sourceBundleIdentifier:
                sourceBundleIdentifier,
            origin: origin,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            customTitle: customTitle
        )
    }

    init(
        id: UUID = UUID(),
        payload: ClipboardPayload,
        createdAt: Date = Date(),
        kind: ClipboardItemKind = .normal,
        sourceAppName: String? = nil,
        sourceBundleIdentifier: String? = nil,
        origin: ClipboardItemOrigin = .captured,
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        customTitle: String? = nil
    ) {
        self.id = id
        self.payload = payload
        self.createdAt = createdAt
        self.kind = kind
        self.sourceAppName = sourceAppName
        self.sourceBundleIdentifier =
            sourceBundleIdentifier
        self.origin = origin
        self.isPinned =
            kind == .normal &&
            isPinned
        self.pinnedAt =
            self.isPinned
                ? pinnedAt
                : nil

        self.customTitle =
            ClipboardItem.normalizedCustomTitle(
                customTitle
            )
    }

    func pinnedCopy(
        pinnedAt: Date = Date()
    ) -> ClipboardItem {
        guard kind == .normal else {
            return self
        }

        return ClipboardItem(
            id: id,
            payload: payload,
            createdAt: createdAt,
            kind: kind,
            sourceAppName: sourceAppName,
            sourceBundleIdentifier:
                sourceBundleIdentifier,
            origin: origin,
            isPinned: true,
            pinnedAt: pinnedAt,
            customTitle: customTitle
        )
    }

    func unpinnedCopy() -> ClipboardItem {
        ClipboardItem(
            id: id,
            payload: payload,
            createdAt: createdAt,
            kind: kind,
            sourceAppName: sourceAppName,
            sourceBundleIdentifier:
                sourceBundleIdentifier,
            origin: origin,
            isPinned: false,
            pinnedAt: nil,
            customTitle: customTitle
        )
    }
    
    func renamedCopy(
        customTitle:
            String?
    ) -> ClipboardItem {
        guard kind == .normal else {
            return self
        }

        return ClipboardItem(
            id: id,
            payload: payload,
            createdAt: createdAt,
            kind: kind,
            sourceAppName: sourceAppName,
            sourceBundleIdentifier:
                sourceBundleIdentifier,
            origin: origin,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            customTitle: customTitle
        )
    }

    func restoredCopy() -> ClipboardItem {
        ClipboardItem(
            id: id,
            payload: payload,
            createdAt: createdAt,
            kind: kind,
            sourceAppName: sourceAppName,
            sourceBundleIdentifier:
                sourceBundleIdentifier,
            origin: .restored,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            customTitle: customTitle
        )
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case id
        case payload
        case text
        case createdAt
        case kind
        case sourceAppName
        case sourceBundleIdentifier
        case origin
        case contentKind
        case isPinned
        case pinnedAt
        case customTitle
    }

    init(from decoder: Decoder) throws {
        let container =
            try decoder.container(
                keyedBy: CodingKeys.self
            )

        id = try container.decode(
            UUID.self,
            forKey: .id
        )

        createdAt = try container.decode(
            Date.self,
            forKey: .createdAt
        )

        kind = try container.decode(
            ClipboardItemKind.self,
            forKey: .kind
        )

        sourceAppName =
            try container.decodeIfPresent(
                String.self,
                forKey: .sourceAppName
            )

        sourceBundleIdentifier =
            try container.decodeIfPresent(
                String.self,
                forKey:
                    .sourceBundleIdentifier
            )

        origin =
            try container.decodeIfPresent(
                ClipboardItemOrigin.self,
                forKey: .origin
            ) ??
            .captured

        if let decodedPayload =
            try container.decodeIfPresent(
                ClipboardPayload.self,
                forKey: .payload
            )
        {
            payload = decodedPayload
        } else {
            let legacyText =
                try container.decode(
                    String.self,
                    forKey: .text
                )

            let legacyContentKind =
                try container.decodeIfPresent(
                    ClipboardContentKind.self,
                    forKey: .contentKind
                )

            payload =
                ClipboardItem.payload(
                    from: legacyText,
                    itemKind: kind,
                    explicitContentKind:
                        legacyContentKind
                )
        }

        let decodedIsPinned =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .isPinned
            ) ??
            false

        isPinned =
            kind == .normal &&
            decodedIsPinned

        if isPinned {
            pinnedAt =
                try container.decodeIfPresent(
                    Date.self,
                    forKey: .pinnedAt
                )
        } else {
            pinnedAt = nil
        }

        customTitle =
            ClipboardItem.normalizedCustomTitle(
                try container.decodeIfPresent(
                    String.self,
                    forKey:
                        .customTitle
                )
            )
    }

    func encode(
        to encoder: Encoder
    ) throws {
        var container =
            encoder.container(
                keyedBy: CodingKeys.self
            )

        try container.encode(
            id,
            forKey: .id
        )

        try container.encode(
            payload,
            forKey: .payload
        )

        try container.encode(
            text,
            forKey: .text
        )

        try container.encode(
            createdAt,
            forKey: .createdAt
        )

        try container.encode(
            kind,
            forKey: .kind
        )

        try container.encodeIfPresent(
            sourceAppName,
            forKey: .sourceAppName
        )

        try container.encodeIfPresent(
            sourceBundleIdentifier,
            forKey:
                .sourceBundleIdentifier
        )

        try container.encode(
            origin,
            forKey: .origin
        )

        try container.encode(
            contentKind,
            forKey: .contentKind
        )

        try container.encode(
            isPinned,
            forKey: .isPinned
        )

        try container.encodeIfPresent(
            pinnedAt,
            forKey: .pinnedAt
        )

        try container.encodeIfPresent(
            customTitle,
            forKey: .customTitle
        )
    }
    
    private static func normalizedCustomTitle(
        _ value:
            String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue =
            value.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        return trimmedValue.isEmpty
            ? nil
            : trimmedValue
    }

    private static func payload(
        from text: String,
        itemKind: ClipboardItemKind,
        explicitContentKind:
            ClipboardContentKind?
    ) -> ClipboardPayload {
        guard itemKind == .normal else {
            return .text(
                ClipboardTextPayload(
                    text: text
                )
            )
        }

        switch explicitContentKind {
        case .link:
            return .link(
                ClipboardLinkPayload(
                    urlString: text
                )
            )

        case .text:
            return .text(
                ClipboardTextPayload(
                    text: text
                )
            )

        case .image, .files:
            return ClipboardPayload.inferred(
                from: text,
                itemKind: itemKind
            )

        case nil:
            return ClipboardPayload.inferred(
                from: text,
                itemKind: itemKind
            )
        }
    }
}
