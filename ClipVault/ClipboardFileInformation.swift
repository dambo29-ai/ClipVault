//
//  ClipboardFileInformation.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/21/26.
//

import Foundation

enum ClipboardFileInformationKind:
    String,
    Equatable,
    Sendable
{
    case folder
    case finderAlias
    case symbolicLink

    var displayName:
        String
    {
        switch self {
        case .folder:
            return "Folder"

        case .finderAlias:
            return "Finder Alias"

        case .symbolicLink:
            return "Symbolic Link"
        }
    }
}

struct ClipboardFileInformation:
    Equatable,
    Sendable
{
    let kind:
        ClipboardFileInformationKind

    let displayName:
        String

    let originalURL:
        URL

    let modifiedDate:
        Date?

    let itemCount:
        Int?

    let destination:
        String?

    let destinationExists:
        Bool?

    var itemCountText:
        String?
    {
        guard let itemCount else {
            return nil
        }

        return itemCount == 1
            ? "1 item"
            : "\(itemCount) items"
    }

    var destinationStatusText:
        String?
    {
        guard
            let destinationExists
        else {
            return nil
        }

        return destinationExists
            ? "Available"
            : "Unavailable"
    }
}

enum ClipboardFileInformationReaderError:
    LocalizedError,
    Equatable
{
    case unsupportedItem
    case metadataUnavailable

    var errorDescription:
        String?
    {
        switch self {
        case .unsupportedItem:
            return
                "This item does not use ClipVault’s information preview."

        case .metadataUnavailable:
            return
                "ClipVault could not read information about this item."
        }
    }
}

struct ClipboardFileInformationReader:
    Sendable
{
    typealias AliasResolver =
        @Sendable (URL) throws -> URL

    typealias FileExists =
        @Sendable (String) -> Bool

    typealias DirectoryItemCounter =
        @Sendable (URL) throws -> Int

    private let aliasResolver:
        AliasResolver

    private let fileExists:
        FileExists

    private let directoryItemCounter:
        DirectoryItemCounter

    init(
        aliasResolver:
            @escaping AliasResolver = {
                aliasURL in

                try URL(
                    resolvingAliasFileAt:
                        aliasURL,
                    options: [
                        .withoutUI,
                        .withoutMounting
                    ]
                )
            },
        fileExists:
            @escaping FileExists = {
                path in

                FileManager.default
                    .fileExists(
                        atPath:
                            path
                    )
            },
        directoryItemCounter:
            @escaping DirectoryItemCounter = {
                directoryURL in

                try FileManager.default
                    .contentsOfDirectory(
                        at:
                            directoryURL,
                        includingPropertiesForKeys:
                            nil,
                        options: [
                            .skipsHiddenFiles
                        ]
                    )
                    .count
            }
    ) {
        self.aliasResolver =
            aliasResolver

        self.fileExists =
            fileExists

        self.directoryItemCounter =
            directoryItemCounter
    }

    func information(
        for reference:
            ClipboardFileReference,
        resolvedURL:
            URL
    ) throws -> ClipboardFileInformation {
        if reference.isSymbolicLink {
            return symbolicLinkInformation(
                for:
                    reference
            )
        }

        let resourceValues:
            URLResourceValues

        do {
            resourceValues =
                try resolvedURL
                    .resourceValues(
                        forKeys: [
                            .isDirectoryKey,
                            .isAliasFileKey,
                            .contentModificationDateKey,
                            .nameKey
                        ]
                    )
        } catch {
            throw ClipboardFileInformationReaderError
                .metadataUnavailable
        }

        if resourceValues.isAliasFile == true {
            return aliasInformation(
                for:
                    reference,
                resolvedURL:
                    resolvedURL,
                modifiedDate:
                    resourceValues
                        .contentModificationDate
            )
        }

        if resourceValues.isDirectory == true ||
            reference.isDirectory
        {
            let itemCount =
                try? directoryItemCounter(
                    resolvedURL
                )

            return ClipboardFileInformation(
                kind:
                    .folder,
                displayName:
                    reference.displayName,
                originalURL:
                    resolvedURL,
                modifiedDate:
                    resourceValues
                        .contentModificationDate,
                itemCount:
                    itemCount,
                destination:
                    nil,
                destinationExists:
                    nil
            )
        }

        throw ClipboardFileInformationReaderError
            .unsupportedItem
    }
    
#if DEBUG
func aliasInformationForTesting(
    reference:
        ClipboardFileReference,
    resolvedURL:
        URL,
    modifiedDate:
        Date? = nil
) -> ClipboardFileInformation {
    aliasInformation(
        for:
            reference,
        resolvedURL:
            resolvedURL,
        modifiedDate:
            modifiedDate
    )
}
#endif

    private func aliasInformation(
        for reference:
            ClipboardFileReference,
        resolvedURL:
            URL,
        modifiedDate:
            Date?
    ) -> ClipboardFileInformation {
        let targetURL =
            try? aliasResolver(
                resolvedURL
            )
            .standardizedFileURL

        return ClipboardFileInformation(
            kind:
                .finderAlias,
            displayName:
                reference.displayName,
            originalURL:
                resolvedURL,
            modifiedDate:
                modifiedDate,
            itemCount:
                nil,
            destination:
                targetURL?
                    .path,
            destinationExists:
                targetURL.map {
                    fileExists(
                        $0.path
                    )
                }
        )
    }

    private func symbolicLinkInformation(
        for reference:
            ClipboardFileReference
    ) -> ClipboardFileInformation {
        let destination =
            reference.symbolicLinkDestination

        let targetURL:
            URL?

        if let destination {
            if destination.hasPrefix(
                "/"
            ) {
                targetURL =
                    URL(
                        fileURLWithPath:
                            destination
                    )
                    .standardizedFileURL
            } else {
                targetURL =
                    reference
                        .fileURL
                        .deletingLastPathComponent()
                        .appendingPathComponent(
                            destination
                        )
                        .standardizedFileURL
            }
        } else {
            targetURL =
                nil
        }

        return ClipboardFileInformation(
            kind:
                .symbolicLink,
            displayName:
                reference.displayName,
            originalURL:
                reference.fileURL,
            modifiedDate:
                (
                    try? reference
                        .fileURL
                        .resourceValues(
                            forKeys: [
                                .contentModificationDateKey
                            ]
                        )
                )?
                .contentModificationDate,
            itemCount:
                nil,
            destination:
                destination,
            destinationExists:
                targetURL.map {
                    fileExists(
                        $0.path
                    )
                }
        )
    }
}
