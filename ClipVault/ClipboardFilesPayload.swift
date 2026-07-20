//
//  ClipboardFilesPayload.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/17/26.
//

import Foundation

struct ClipboardFileReference:
    Codable,
    Equatable,
    Sendable
{
    let path: String
    let displayName: String
    let isDirectory: Bool
    let byteCount: Int?
    let bookmarkData: Data?

    let symbolicLinkIdentifier:
        UUID?

    let symbolicLinkDestination:
        String?

    nonisolated init(
        path: String,
        displayName: String,
        isDirectory: Bool,
        byteCount: Int? = nil,
        bookmarkData: Data? = nil,
        symbolicLinkIdentifier:
            UUID? = nil,
        symbolicLinkDestination:
            String? = nil
    ) {
        let cleanedPath =
            path.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanedDisplayName =
            displayName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        self.path =
            cleanedPath

        if cleanedDisplayName.isEmpty {
            self.displayName =
                URL(
                    fileURLWithPath:
                        cleanedPath
                )
                .lastPathComponent
        } else {
            self.displayName =
                cleanedDisplayName
        }

        self.isDirectory =
            isDirectory

        if let byteCount {
            self.byteCount =
                max(
                    0,
                    byteCount
                )
        } else {
            self.byteCount =
                nil
        }

        self.bookmarkData =
            bookmarkData

        self.symbolicLinkIdentifier =
            symbolicLinkIdentifier

        let cleanedSymbolicLinkDestination =
            symbolicLinkDestination?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        self.symbolicLinkDestination =
            cleanedSymbolicLinkDestination?
                .isEmpty == false
                ? cleanedSymbolicLinkDestination
                : nil
    }
    
    var isSymbolicLink: Bool {
        symbolicLinkIdentifier != nil &&
        symbolicLinkDestination != nil
    }

    var fileURL: URL {
        URL(
            fileURLWithPath:
                path
        )
    }

    var kindDisplayName: String {
        if isSymbolicLink {
            return "Symbolic Link"
        }

        guard !isDirectory else {
            return "Folder"
        }

        let filenameExtension =
            fileURL
                .pathExtension
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !filenameExtension.isEmpty
        else {
            return "File"
        }

        return filenameExtension
            .uppercased()
    }

    var byteCountText: String? {
        guard
            !isDirectory,
            let byteCount
        else {
            return nil
        }

        let formatter =
            ByteCountFormatter()

        formatter.countStyle =
            .file

        formatter.includesUnit =
            true

        formatter.includesCount =
            true

        formatter.isAdaptive =
            true

        return formatter.string(
            fromByteCount:
                Int64(byteCount)
        )
    }
    
    var rowMetadataText: String {
        [
            kindDisplayName,
            byteCountText
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " • ")
    }

    var searchableText: String {
        [
            displayName,
            path,
            kindDisplayName,
            byteCountText
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    var duplicateComponent: String {
        if let symbolicLinkDestination {
            return [
                "symbolic-link",
                fileURL
                    .standardizedFileURL
                    .path
                    .lowercased(),
                symbolicLinkDestination
            ]
            .joined(
                separator:
                    "|"
            )
        }

        return fileURL
            .standardizedFileURL
            .path
            .lowercased()
    }
}

struct ClipboardFilesPayload:
    Codable,
    Equatable,
    Sendable
{
    let files: [ClipboardFileReference]

    nonisolated init(
        files: [ClipboardFileReference]
    ) {
        self.files =
            files
    }

    var displayTitle: String {
        guard
            let firstFile =
                files.first
        else {
            return "Copied Files"
        }

        guard files.count > 1 else {
            return firstFile.displayName
        }

        return "\(files.count) Items"
    }

    var itemCountText: String {
        guard files.count != 1 else {
            return "1 Item"
        }

        return "\(files.count) Items"
    }

    var compositionText: String {
        let fileCount =
            files.filter {
                !$0.isDirectory
            }
            .count

        let folderCount =
            files.filter {
                $0.isDirectory
            }
            .count

        var components: [String] = []

        if fileCount > 0 {
            components.append(
                fileCount == 1
                    ? "1 File"
                    : "\(fileCount) Files"
            )
        }

        if folderCount > 0 {
            components.append(
                folderCount == 1
                    ? "1 Folder"
                    : "\(folderCount) Folders"
            )
        }

        return components.isEmpty
            ? itemCountText
            : components.joined(
                separator: " • "
            )
    }

    var rowMetadataText: String {
        guard files.count > 1 else {
            guard
                let file =
                    files.first
            else {
                return itemCountText
            }

            return file.rowMetadataText
        }

        return compositionText
    }

    var searchableText: String {
        let fileSearchText =
            files
                .map(\.searchableText)
                .joined(separator: " ")

        return [
            displayTitle,
            itemCountText,
            compositionText,
            fileSearchText
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    var duplicateKey: String {
        let components =
            files
                .map(\.duplicateComponent)
                .sorted()
                .joined(separator: "\n")

        return "files:\(components)"
    }
}
