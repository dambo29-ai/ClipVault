//
//  ClipboardBackupPackageService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/17/26.
//

import AppKit
import Foundation

struct ClipboardBackupPackageManifest:
    Codable,
    Equatable
{
    let appName: String
    let formatVersion: Int
    let exportedAt: Date
    let items: [ClipboardItem]
}

enum ClipboardBackupPackageError:
    LocalizedError,
    Equatable
{
    case noHistory
    case packageAlreadyExists
    case invalidPackageExtension
    case applicationSupportUnavailable
    case noBackupsFound

    var errorDescription: String? {
        switch self {
        case .noHistory:
            return
                "ClipVault does not have any saved clipboard history yet."

        case .packageAlreadyExists:
            return
                "A backup package with this name already exists."

        case .invalidPackageExtension:
            return
                "ClipVault backup packages must use the .clipvaultbackup extension."
        
        case .applicationSupportUnavailable:
            return
                "The Application Support folder could not be located."
            
        case .noBackupsFound:
            return
                "ClipVault could not find any .clipvaultbackup packages in the Exports folder."
        }
    }
}

@MainActor
final class ClipboardBackupPackageService {
    static let shared =
        ClipboardBackupPackageService(
            imageStorageService:
                .shared
        )

    static let packageExtension =
        "clipvaultbackup"

    static let manifestFilename =
        "manifest.json"

    static let imagesFolderName =
        "Images"

    static let currentFormatVersion =
        2

    private let imageStorageService:
        ClipboardImageStorageService

    private let customExportsDirectoryURL:
        URL?

    private init(
        imageStorageService:
            ClipboardImageStorageService
    ) {
        self.imageStorageService =
            imageStorageService

        customExportsDirectoryURL =
            nil
    }

    init(
        exportsDirectoryURL: URL,
        imageStorageService:
            ClipboardImageStorageService
    ) {
        self.imageStorageService =
            imageStorageService

        customExportsDirectoryURL =
            exportsDirectoryURL
    }

    func exportBackup(
        items: [ClipboardItem],
        exportedAt: Date = Date()
    ) async throws -> URL {
        let normalItems =
            items.filter {
                $0.kind == .normal
            }

        guard !normalItems.isEmpty else {
            throw ClipboardBackupPackageError
                .noHistory
        }

        let exportsDirectoryURL =
            try resolvedExportsDirectoryURL()

        let finalPackageURL =
            makeUniquePackageURL(
                in: exportsDirectoryURL,
                exportedAt: exportedAt
            )

        guard
            finalPackageURL
                .pathExtension
                .lowercased() ==
                Self.packageExtension
        else {
            throw ClipboardBackupPackageError
                .invalidPackageExtension
        }

        let temporaryPackageURL =
            exportsDirectoryURL
                .appendingPathComponent(
                    ".\(UUID().uuidString)." +
                    Self.packageExtension,
                    isDirectory: true
                )

        do {
            try FileManager.default
                .createDirectory(
                    at:
                        temporaryPackageURL,
                    withIntermediateDirectories:
                        false
                )

            let imagesDirectoryURL =
                temporaryPackageURL
                    .appendingPathComponent(
                        Self.imagesFolderName,
                        isDirectory: true
                    )

            try FileManager.default
                .createDirectory(
                    at:
                        imagesDirectoryURL,
                    withIntermediateDirectories:
                        false
                )

            try await writeImageAssets(
                for: normalItems,
                to:
                    imagesDirectoryURL
            )

            try writeManifest(
                items: normalItems,
                exportedAt:
                    exportedAt,
                to:
                    temporaryPackageURL
            )

            guard
                !FileManager.default
                    .fileExists(
                        atPath:
                            finalPackageURL.path
                    )
            else {
                throw ClipboardBackupPackageError
                    .packageAlreadyExists
            }

            try FileManager.default
                .moveItem(
                    at:
                        temporaryPackageURL,
                    to:
                        finalPackageURL
                )

            return finalPackageURL
        } catch {
            try? FileManager.default
                .removeItem(
                    at:
                        temporaryPackageURL
                )

            throw error
        }
    }

    func latestBackupURL() throws -> URL {
        let backupURLs =
            try sortedBackupURLsNewestFirst()

        guard
            let latestBackupURL =
                backupURLs.first
        else {
            throw ClipboardBackupPackageError
                .noBackupsFound
        }

        return latestBackupURL
    }

    func revealLatestBackup() throws {
        let latestBackupURL =
            try latestBackupURL()

        NSWorkspace.shared
            .activateFileViewerSelecting([
                latestBackupURL
            ])
    }

    func deleteOldBackups(
        keepingMostRecent keepCount: Int
    ) throws -> BackupCleanupResult {
        let safeKeepCount =
            max(
                keepCount,
                1
            )

        let backupURLs =
            try sortedBackupURLsNewestFirst()

        guard !backupURLs.isEmpty else {
            throw ClipboardBackupPackageError
                .noBackupsFound
        }

        let backupURLsToKeep =
            Array(
                backupURLs.prefix(
                    safeKeepCount
                )
            )

        let backupURLsToDelete =
            Array(
                backupURLs.dropFirst(
                    safeKeepCount
                )
            )

        for backupURL in
            backupURLsToDelete
        {
            try FileManager.default
                .removeItem(
                    at:
                        backupURL
                )
        }

        return BackupCleanupResult(
            deletedCount:
                backupURLsToDelete.count,
            keptCount:
                backupURLsToKeep.count
        )
    }

    private func sortedBackupURLsNewestFirst()
        throws -> [URL]
    {
        let exportsDirectoryURL =
            try resolvedExportsDirectoryURL()

        let candidateURLs =
            try FileManager.default
                .contentsOfDirectory(
                    at:
                        exportsDirectoryURL,
                    includingPropertiesForKeys: [
                        .isDirectoryKey
                    ],
                    options: [
                        .skipsHiddenFiles
                    ]
                )

        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601

        let validBackups:
            [(url: URL, exportedAt: Date)] =
                candidateURLs.compactMap {
                    packageURL in

                    guard
                        packageURL
                            .pathExtension
                            .lowercased() ==
                            Self.packageExtension
                    else {
                        return nil
                    }

                    let resourceValues =
                        try? packageURL
                            .resourceValues(
                                forKeys: [
                                    .isDirectoryKey
                                ]
                            )

                    guard
                        resourceValues?
                            .isDirectory ==
                            true
                    else {
                        return nil
                    }

                    let manifestURL =
                        packageURL
                            .appendingPathComponent(
                                Self.manifestFilename,
                                isDirectory:
                                    false
                            )

                    guard
                        let manifestData =
                            try? Data(
                                contentsOf:
                                    manifestURL
                            ),
                        let manifest =
                            try? decoder.decode(
                                ClipboardBackupPackageManifest
                                    .self,
                                from:
                                    manifestData
                            ),
                        manifest.appName ==
                            "ClipVault",
                        manifest.formatVersion ==
                            Self.currentFormatVersion
                    else {
                        return nil
                    }

                    return (
                        url:
                            packageURL,
                        exportedAt:
                            manifest.exportedAt
                    )
                }

        return validBackups
            .sorted {
                firstBackup,
                secondBackup in

                if firstBackup.exportedAt !=
                    secondBackup.exportedAt
                {
                    return
                        firstBackup.exportedAt >
                        secondBackup.exportedAt
                }

                return
                    firstBackup
                        .url
                        .lastPathComponent
                        .localizedStandardCompare(
                            secondBackup
                                .url
                                .lastPathComponent
                        ) ==
                        .orderedDescending
            }
            .map(\.url)
    }
    
    private func writeManifest(
        items: [ClipboardItem],
        exportedAt: Date,
        to packageURL: URL
    ) throws {
        let manifest =
            ClipboardBackupPackageManifest(
                appName:
                    "ClipVault",
                formatVersion:
                    Self
                        .currentFormatVersion,
                exportedAt:
                    exportedAt,
                items:
                    items
            )

        let encoder =
            JSONEncoder()

        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        encoder.dateEncodingStrategy =
            .iso8601

        let data =
            try encoder.encode(
                manifest
            )

        let manifestURL =
            packageURL
                .appendingPathComponent(
                    Self.manifestFilename,
                    isDirectory: false
                )

        try data.write(
            to: manifestURL,
            options: [.atomic]
        )
    }

    private func writeImageAssets(
        for items: [ClipboardItem],
        to imagesDirectoryURL: URL
    ) async throws {
        var copiedStorageIdentifiers:
            Set<UUID> = []

        for item in items {
            guard
                let imagePayload =
                    item.imagePayload
            else {
                continue
            }

            guard
                copiedStorageIdentifiers
                    .insert(
                        imagePayload
                            .storageIdentifier
                    )
                    .inserted
            else {
                continue
            }

            let imageData =
                try await imageStorageService
                    .loadImageData(
                        for:
                            imagePayload
                    )

            let destinationURL =
                imagesDirectoryURL
                    .appendingPathComponent(
                        imagePayload
                            .storedFilename,
                        isDirectory: false
                    )

            try imageData.write(
                to:
                    destinationURL,
                options: [.atomic]
            )
        }
    }

    private func resolvedExportsDirectoryURL()
        throws -> URL
    {
        let exportsDirectoryURL:
            URL

        if let customExportsDirectoryURL {
            exportsDirectoryURL =
                customExportsDirectoryURL
        } else {
            guard
                let applicationSupportURL =
                    FileManager.default
                        .urls(
                            for:
                                .applicationSupportDirectory,
                            in:
                                .userDomainMask
                        )
                        .first
            else {
                throw ClipboardBackupPackageError
                    .applicationSupportUnavailable
            }

            exportsDirectoryURL =
                applicationSupportURL
                    .appendingPathComponent(
                        "ClipVault",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "Exports",
                        isDirectory: true
                    )
        }

        try FileManager.default
            .createDirectory(
                at:
                    exportsDirectoryURL,
                withIntermediateDirectories:
                    true
            )

        return exportsDirectoryURL
    }

    private func makeUniquePackageURL(
        in exportsDirectoryURL: URL,
        exportedAt: Date
    ) -> URL {
        let dateFormatter =
            DateFormatter()

        dateFormatter.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        dateFormatter.calendar =
            Calendar(
                identifier:
                    .gregorian
            )

        dateFormatter.timeZone =
            .current

        dateFormatter.dateFormat =
            "yyyy-MM-dd HH-mm-ss"

        let timestamp =
            dateFormatter.string(
                from:
                    exportedAt
            )

        let baseName =
            "ClipVault Backup \(timestamp)"

        var candidateURL =
            exportsDirectoryURL
                .appendingPathComponent(
                    baseName
                )
                .appendingPathExtension(
                    Self.packageExtension
                )

        var suffix =
            2

        while FileManager.default
            .fileExists(
                atPath:
                    candidateURL.path
            )
        {
            candidateURL =
                exportsDirectoryURL
                    .appendingPathComponent(
                        "\(baseName) \(suffix)"
                    )
                    .appendingPathExtension(
                        Self.packageExtension
                    )

            suffix += 1
        }

        return candidateURL
    }
}
