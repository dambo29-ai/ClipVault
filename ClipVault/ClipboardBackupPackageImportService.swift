//
//  ClipboardBackupPackageImportService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/17/26.
//

import CryptoKit
import Foundation
import ImageIO

struct ClipboardBackupPackageContents:
    Equatable
{
    let packageURL: URL

    let manifest:
        ClipboardBackupPackageManifest

    let imageDataByStorageIdentifier:
        [UUID: Data]
}

struct ClipboardBackupPackageRestoration:
    Equatable
{
    let items: [ClipboardItem]

    let restoredImagePayloads:
        [ClipboardImagePayload]
}

enum ClipboardBackupPackageImportError:
    LocalizedError,
    Equatable
{
    case invalidPackageExtension
    case packageNotFound
    case packageIsNotDirectory
    case manifestMissing
    case invalidManifest
    case invalidAppName
    case unsupportedFormatVersion
    case noImportableItems
    case invalidImageFilename
    case missingImageAsset(
        filename: String
    )
    case corruptedImageAsset(
        filename: String
    )
    case duplicateImageStorageIdentifier(
        storageIdentifier: UUID
    )

    case missingValidatedImageData(
        storageIdentifier: UUID
    )

    var errorDescription: String? {
        switch self {
        case .invalidPackageExtension:
            return
                "The selected file is not a .clipvaultbackup package."

        case .packageNotFound:
            return
                "The selected backup package could not be found."

        case .packageIsNotDirectory:
            return
                "The selected .clipvaultbackup item is not a valid package directory."

        case .manifestMissing:
            return
                "The backup package does not contain manifest.json."

        case .invalidManifest:
            return
                "The backup manifest could not be read."

        case .invalidAppName:
            return
                "The backup was not created by ClipVault."

        case .unsupportedFormatVersion:
            return
                "This backup uses an unsupported ClipVault backup format."

        case .noImportableItems:
            return
                "The backup does not contain any importable clipboard history."

        case .invalidImageFilename:
            return
                "The backup contains invalid image asset metadata."

        case let .missingImageAsset(filename):
            return
                "The backup is missing the image asset “\(filename)”."

        case let .corruptedImageAsset(filename):
            return
                "The image asset “\(filename)” is damaged or does not match the backup manifest."

        case let .duplicateImageStorageIdentifier(
            storageIdentifier
        ):
            return
                "The backup contains duplicate image metadata for \(storageIdentifier.uuidString)."
            
        case let .missingValidatedImageData(
            storageIdentifier
        ):
            return
                "ClipVault could not restore the validated image asset \(storageIdentifier.uuidString)."
        }
    }
}

@MainActor
final class ClipboardBackupPackageImportService {
    static let shared =
        ClipboardBackupPackageImportService(
            imageStorageService:
                .shared
        )

    private let imageStorageService:
        ClipboardImageStorageService

    private init(
        imageStorageService:
            ClipboardImageStorageService
    ) {
        self.imageStorageService =
            imageStorageService
    }

    init(
        restoringInto imageStorageService:
            ClipboardImageStorageService
    ) {
        self.imageStorageService =
            imageStorageService
    }

    func readPackage(
        at packageURL: URL
    ) throws
        -> ClipboardBackupPackageContents
    {
        guard
            packageURL
                .pathExtension
                .lowercased() ==
                ClipboardBackupPackageService
                    .packageExtension
        else {
            throw ClipboardBackupPackageImportError
                .invalidPackageExtension
        }

        guard
            FileManager.default
                .fileExists(
                    atPath:
                        packageURL.path
                )
        else {
            throw ClipboardBackupPackageImportError
                .packageNotFound
        }

        let packageResourceValues =
            try? packageURL
                .resourceValues(
                    forKeys: [
                        .isDirectoryKey
                    ]
                )

        guard
            packageResourceValues?
                .isDirectory ==
                true
        else {
            throw ClipboardBackupPackageImportError
                .packageIsNotDirectory
        }

        let didStartAccessing =
            packageURL
                .startAccessingSecurityScopedResource()

        defer {
            if didStartAccessing {
                packageURL
                    .stopAccessingSecurityScopedResource()
            }
        }

        let manifest =
            try readManifest(
                from:
                    packageURL
            )

        let normalItems =
            manifest.items.filter {
                $0.kind == .normal
            }

        guard !normalItems.isEmpty else {
            throw ClipboardBackupPackageImportError
                .noImportableItems
        }

        let imageDataByStorageIdentifier =
            try readAndValidateImageAssets(
                for:
                    normalItems,
                in:
                    packageURL
            )

        return ClipboardBackupPackageContents(
            packageURL:
                packageURL,
            manifest:
                ClipboardBackupPackageManifest(
                    appName:
                        manifest.appName,
                    formatVersion:
                        manifest.formatVersion,
                    exportedAt:
                        manifest.exportedAt,
                    items:
                        normalItems
                ),
            imageDataByStorageIdentifier:
                imageDataByStorageIdentifier
        )
    }
    
    func restorePackage(
        _ contents:
            ClipboardBackupPackageContents
    ) async throws
        -> ClipboardBackupPackageRestoration
    {
        var restoredPayloadByOriginalStorageIdentifier:
            [UUID: ClipboardImagePayload] =
                [:]

        var newlyStoredPayloads:
            [ClipboardImagePayload] = []

        do {
            for item in
                contents.manifest.items
            {
                guard
                    let originalImagePayload =
                        item.imagePayload
                else {
                    continue
                }

                let originalStorageIdentifier =
                    originalImagePayload
                        .storageIdentifier

                guard
                    restoredPayloadByOriginalStorageIdentifier[
                        originalStorageIdentifier
                    ] == nil
                else {
                    continue
                }

                guard
                    let imageData =
                        contents
                            .imageDataByStorageIdentifier[
                                originalStorageIdentifier
                            ]
                else {
                    throw ClipboardBackupPackageImportError
                        .missingValidatedImageData(
                            storageIdentifier:
                                originalStorageIdentifier
                        )
                }

                let restoredPayload =
                    try await imageStorageService
                        .storeImage(
                            data:
                                imageData,
                            originalFilename:
                                originalImagePayload
                                    .originalFilename,
                            wasConverted:
                                originalImagePayload
                                    .wasConverted,
                            originalFileReference:
                                originalImagePayload
                                    .originalFileReference
                        )

                restoredPayloadByOriginalStorageIdentifier[
                    originalStorageIdentifier
                ] = restoredPayload

                newlyStoredPayloads.append(
                    restoredPayload
                )
            }

            let restoredItems =
                try contents
                    .manifest
                    .items
                    .map {
                        item in

                        try restoredItem(
                            from: item,
                            restoredPayloadByOriginalStorageIdentifier:
                                restoredPayloadByOriginalStorageIdentifier
                        )
                    }

            return ClipboardBackupPackageRestoration(
                items:
                    restoredItems,
                restoredImagePayloads:
                    newlyStoredPayloads
            )
        } catch {
            for restoredPayload in
                newlyStoredPayloads
            {
                try? await imageStorageService
                    .deleteImage(
                        for:
                            restoredPayload
                    )
            }

            throw error
        }
    }
    
    func deleteUnretainedRestoredImageAssets(
        from restoration:
            ClipboardBackupPackageRestoration,
        retainedItems:
            [ClipboardItem]
    ) async {
        let retainedStorageIdentifiers =
            Set(
                retainedItems.compactMap {
                    $0.imagePayload?
                        .storageIdentifier
                }
            )

        for restoredImagePayload in
            restoration
                .restoredImagePayloads
        {
            guard
                !retainedStorageIdentifiers
                    .contains(
                        restoredImagePayload
                            .storageIdentifier
                    )
            else {
                continue
            }

            try? await imageStorageService
                .deleteImage(
                    for:
                        restoredImagePayload
                )
        }
    }

    func readLatestPackage()
        throws
        -> ClipboardBackupPackageContents
    {
        let latestPackageURL =
            try ClipboardBackupPackageService
                .shared
                .latestBackupURL()

        return try readPackage(
            at:
                latestPackageURL
        )
    }
    
    private func restoredItem(
        from item: ClipboardItem,
        restoredPayloadByOriginalStorageIdentifier:
            [UUID: ClipboardImagePayload]
    ) throws -> ClipboardItem {
        let restoredPayload:
            ClipboardPayload

        switch item.payload {
        case let .text(textPayload):
            restoredPayload =
                .text(
                    textPayload
                )

        case let .link(linkPayload):
            restoredPayload =
                .link(
                    linkPayload
                )

        case let .image(
            originalImagePayload
        ):
            guard
                let restoredImagePayload =
                    restoredPayloadByOriginalStorageIdentifier[
                        originalImagePayload
                            .storageIdentifier
                    ]
            else {
                throw ClipboardBackupPackageImportError
                    .missingValidatedImageData(
                        storageIdentifier:
                            originalImagePayload
                                .storageIdentifier
                    )
            }

            restoredPayload =
                .image(
                    restoredImagePayload
                )

        case let .files(filesPayload):
            restoredPayload =
                .files(
                    filesPayload
                )
        }

        return ClipboardItem(
            id:
                item.id,
            payload:
                restoredPayload,
            createdAt:
                item.createdAt,
            kind:
                item.kind,
            sourceAppName:
                item.sourceAppName,
            sourceBundleIdentifier:
                item.sourceBundleIdentifier,
            origin:
                .restored,
            isPinned:
                item.isPinned,
            pinnedAt:
                item.pinnedAt
        )
    }

    private func readManifest(
        from packageURL: URL
    ) throws
        -> ClipboardBackupPackageManifest
    {
        let manifestURL =
            packageURL
                .appendingPathComponent(
                    ClipboardBackupPackageService
                        .manifestFilename,
                    isDirectory:
                        false
                )

        guard
            FileManager.default
                .fileExists(
                    atPath:
                        manifestURL.path
                )
        else {
            throw ClipboardBackupPackageImportError
                .manifestMissing
        }

        let manifestData:
            Data

        do {
            manifestData =
                try Data(
                    contentsOf:
                        manifestURL
                )
        } catch {
            throw ClipboardBackupPackageImportError
                .invalidManifest
        }

        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601

        let manifest:
            ClipboardBackupPackageManifest

        do {
            manifest =
                try decoder.decode(
                    ClipboardBackupPackageManifest
                        .self,
                    from:
                        manifestData
                )
        } catch {
            throw ClipboardBackupPackageImportError
                .invalidManifest
        }

        guard
            manifest.appName ==
                "ClipVault"
        else {
            throw ClipboardBackupPackageImportError
                .invalidAppName
        }

        guard
            manifest.formatVersion ==
                ClipboardBackupPackageService
                    .currentFormatVersion
        else {
            throw ClipboardBackupPackageImportError
                .unsupportedFormatVersion
        }

        return manifest
    }

    private func readAndValidateImageAssets(
        for items: [ClipboardItem],
        in packageURL: URL
    ) throws
        -> [UUID: Data]
    {
        let imagesDirectoryURL =
            packageURL
                .appendingPathComponent(
                    ClipboardBackupPackageService
                        .imagesFolderName,
                    isDirectory:
                        true
                )

        var imagePayloadByStorageIdentifier:
            [UUID: ClipboardImagePayload] =
                [:]

        for item in items {
            guard
                let imagePayload =
                    item.imagePayload
            else {
                continue
            }

            let storageIdentifier =
                imagePayload
                    .storageIdentifier

            if let existingPayload =
                imagePayloadByStorageIdentifier[
                    storageIdentifier
                ]
            {
                guard
                    existingPayload ==
                        imagePayload
                else {
                    throw ClipboardBackupPackageImportError
                        .duplicateImageStorageIdentifier(
                            storageIdentifier:
                                storageIdentifier
                        )
                }

                continue
            }

            imagePayloadByStorageIdentifier[
                storageIdentifier
            ] = imagePayload
        }

        var imageDataByStorageIdentifier:
            [UUID: Data] = [:]

        for (
            storageIdentifier,
            imagePayload
        ) in imagePayloadByStorageIdentifier {
            let filename =
                try validatedStoredFilename(
                    for:
                        imagePayload
                )

            let imageURL =
                imagesDirectoryURL
                    .appendingPathComponent(
                        filename,
                        isDirectory:
                            false
                    )

            guard
                FileManager.default
                    .fileExists(
                        atPath:
                            imageURL.path
                    )
            else {
                throw ClipboardBackupPackageImportError
                    .missingImageAsset(
                        filename:
                            filename
                    )
            }

            let imageData:
                Data

            do {
                imageData =
                    try Data(
                        contentsOf:
                            imageURL
                    )
            } catch {
                throw ClipboardBackupPackageImportError
                    .corruptedImageAsset(
                        filename:
                            filename
                    )
            }

            guard
                imageData.count ==
                    imagePayload.byteCount,
                Self.sha256Hash(
                    for:
                        imageData
                ) ==
                    imagePayload.contentHash,
                Self.isValidImageData(
                    imageData
                )
            else {
                throw ClipboardBackupPackageImportError
                    .corruptedImageAsset(
                        filename:
                            filename
                    )
            }

            imageDataByStorageIdentifier[
                storageIdentifier
            ] = imageData
        }

        return imageDataByStorageIdentifier
    }

    private func validatedStoredFilename(
        for imagePayload:
            ClipboardImagePayload
    ) throws -> String {
        let filenameExtension =
            imagePayload
                .format
                .filenameExtension
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        let allowedCharacterSet =
            CharacterSet
                .alphanumerics

        guard
            !filenameExtension.isEmpty,
            filenameExtension.count <= 10,
            filenameExtension.unicodeScalars.allSatisfy(
                {
                    allowedCharacterSet
                        .contains($0)
                }
            )
        else {
            throw ClipboardBackupPackageImportError
                .invalidImageFilename
        }

        return
            imagePayload
                .storageIdentifier
                .uuidString +
            "." +
            filenameExtension
    }

    private nonisolated static func sha256Hash(
        for data: Data
    ) -> String {
        SHA256
            .hash(
                data:
                    data
            )
            .map {
                String(
                    format:
                        "%02x",
                    $0
                )
            }
            .joined()
    }

    private nonisolated static func isValidImageData(
        _ data: Data
    ) -> Bool {
        guard
            let imageSource =
                CGImageSourceCreateWithData(
                    data as CFData,
                    nil
                )
        else {
            return false
        }

        return
            CGImageSourceGetCount(
                imageSource
            ) > 0
    }
}
