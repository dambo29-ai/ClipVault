//
//  ClipboardImageStorageService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

actor ClipboardImageStorageService {
    static let shared =
        ClipboardImageStorageService()

    private let customImagesDirectoryURL: URL?

    private init() {
        customImagesDirectoryURL = nil
    }

    init(
        imagesDirectoryURL: URL
    ) {
        customImagesDirectoryURL =
            imagesDirectoryURL
    }
    
    func storeImage(
        at fileURL: URL,
        wasConverted: Bool = false,
        originalFileReference:
            ClipboardFileReference? = nil
    ) throws -> ClipboardImagePayload {
        let imageData =
            try Data(
                contentsOf: fileURL
            )

        return try storeImage(
            data: imageData,
            originalFilename:
                fileURL.lastPathComponent,
            wasConverted:
                wasConverted,
            originalFileReference:
                originalFileReference
        )
    }

    func storeImage(
        data: Data,
        originalFilename: String? = nil,
        wasConverted: Bool = false,
        originalFileReference:
            ClipboardFileReference? = nil
    ) throws -> ClipboardImagePayload {
        guard !data.isEmpty else {
            throw ClipboardImageStorageError
                .emptyImageData
        }

        let inspectedImage =
            try Self.inspectImageData(
                data
            )

        let storageIdentifier =
            UUID()

        let contentHash =
            Self.sha256Hash(
                for: data
            )

        let payload =
            ClipboardImagePayload(
                storageIdentifier:
                    storageIdentifier,
                format:
                    inspectedImage.format,
                pixelWidth:
                    inspectedImage.pixelWidth,
                pixelHeight:
                    inspectedImage.pixelHeight,
                byteCount:
                    data.count,
                contentHash:
                    contentHash,
                originalFilename:
                    originalFilename,
                wasConverted:
                    wasConverted,
                originalFileReference:
                    originalFileReference
                )

        let fileURL =
            try imageFileURL(
                for: payload
            )

        try data.write(
            to: fileURL,
            options: [.atomic]
        )

        return payload
    }

    func loadImageData(
        for payload: ClipboardImagePayload
    ) throws -> Data {
        let fileURL =
            try imageFileURL(
                for: payload
            )

        guard FileManager.default.fileExists(
            atPath: fileURL.path
        ) else {
            throw ClipboardImageStorageError
                .storedImageMissing
        }

        let data =
            try Data(
                contentsOf: fileURL
            )

        guard
            data.count == payload.byteCount,
            Self.sha256Hash(for: data) ==
                payload.contentHash
        else {
            throw ClipboardImageStorageError
                .storedImageCorrupted
        }

        do {
            _ = try Self.inspectImageData(
                data
            )
        } catch {
            throw ClipboardImageStorageError
                .storedImageCorrupted
        }

        return data
    }

    func validateStoredImage(
        for payload: ClipboardImagePayload
    ) -> Bool {
        do {
            _ = try loadImageData(
                for: payload
            )

            return true
        } catch {
            return false
        }
    }

    func deleteImage(
        for payload: ClipboardImagePayload
    ) throws {
        let fileURL =
            try imageFileURL(
                for: payload
            )

        guard FileManager.default.fileExists(
            atPath: fileURL.path
        ) else {
            return
        }

        try FileManager.default.removeItem(
            at: fileURL
        )
    }

    func imageFileURL(
        for payload: ClipboardImagePayload
    ) throws -> URL {
        let safeExtension =
            try Self.validatedFilenameExtension(
                payload
                    .format
                    .filenameExtension
            )

        let directoryURL =
            try resolvedImagesDirectoryURL()

        let filename =
            "\(payload.storageIdentifier.uuidString)." +
            safeExtension

        return directoryURL.appendingPathComponent(
            filename,
            isDirectory: false
        )
    }

    private func resolvedImagesDirectoryURL()
        throws -> URL
    {
        let directoryURL: URL

        if let customImagesDirectoryURL {
            directoryURL =
                customImagesDirectoryURL
        } else {
            directoryURL =
                try Self.defaultImagesDirectoryURL()
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        return directoryURL
    }

    private nonisolated static func defaultImagesDirectoryURL()
        throws -> URL
    {
        guard
            let applicationSupportURL =
                FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                )
                .first
        else {
            throw ClipboardImageStorageError
                .applicationSupportUnavailable
        }

        return applicationSupportURL
            .appendingPathComponent(
                "ClipVault",
                isDirectory: true
            )
            .appendingPathComponent(
                "Images",
                isDirectory: true
            )
    }

    private nonisolated static func inspectImageData(
        _ data: Data
    ) throws -> InspectedImage {
        guard
            let imageSource =
                CGImageSourceCreateWithData(
                    data as CFData,
                    nil
                ),
            CGImageSourceGetCount(
                imageSource
            ) > 0
        else {
            throw ClipboardImageStorageError
                .invalidImageData
        }

        guard
            let typeIdentifier =
                CGImageSourceGetType(
                    imageSource
                ) as String?,
            let contentType =
                UTType(
                    typeIdentifier
                ),
            contentType.conforms(
                to: .image
            ),
            !contentType.conforms(
                to: .pdf
            )
        else {
            throw ClipboardImageStorageError
                .unsupportedImageFormat
        }

        guard
            let properties =
                CGImageSourceCopyPropertiesAtIndex(
                    imageSource,
                    0,
                    nil
                ) as? [CFString: Any],
            let pixelWidth =
                (
                    properties[
                        kCGImagePropertyPixelWidth
                    ] as? NSNumber
                )?.intValue,
            let pixelHeight =
                (
                    properties[
                        kCGImagePropertyPixelHeight
                    ] as? NSNumber
                )?.intValue,
            pixelWidth > 0,
            pixelHeight > 0
        else {
            throw ClipboardImageStorageError
                .missingImageDimensions
        }

        guard
            let filenameExtension =
                contentType
                    .preferredFilenameExtension,
            !filenameExtension.isEmpty
        else {
            throw ClipboardImageStorageError
                .unsupportedImageFormat
        }

        let format =
            ClipboardImageFormat(
                uniformTypeIdentifier:
                    contentType.identifier,
                filenameExtension:
                    filenameExtension,
                displayName:
                    displayName(
                        for: contentType,
                        filenameExtension:
                            filenameExtension
                    )
            )

        return InspectedImage(
            format: format,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        )
    }

    private nonisolated static func displayName(
        for contentType: UTType,
        filenameExtension: String
    ) -> String {
        switch contentType {
        case .png:
            return "PNG"

        case .jpeg:
            return "JPEG"

        case .tiff:
            return "TIFF"

        case .gif:
            return "GIF"

        case .heic:
            return "HEIC"

        case .heif:
            return "HEIF"

        case .bmp:
            return "BMP"

        default:
            return filenameExtension
                .uppercased()
        }
    }

    private nonisolated static func sha256Hash(
        for data: Data
    ) -> String {
        SHA256.hash(
            data: data
        )
        .map {
            String(
                format: "%02x",
                $0
            )
        }
        .joined()
    }

    private nonisolated static func validatedFilenameExtension(
        _ filenameExtension: String
    ) throws -> String {
        let normalizedExtension =
            filenameExtension
                .trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "."
                    )
                )
                .lowercased()

        guard
            !normalizedExtension.isEmpty,
            normalizedExtension.count <= 16,
            normalizedExtension
                .unicodeScalars
                .allSatisfy({
                    CharacterSet
                        .alphanumerics
                        .contains($0)
                })
        else {
            throw ClipboardImageStorageError
                .invalidFilenameExtension
        }

        return normalizedExtension
    }
}

private struct InspectedImage {
    let format: ClipboardImageFormat
    let pixelWidth: Int
    let pixelHeight: Int
}

enum ClipboardImageStorageError:
    LocalizedError,
    Equatable
{
    case applicationSupportUnavailable
    case emptyImageData
    case invalidImageData
    case unsupportedImageFormat
    case missingImageDimensions
    case invalidFilenameExtension
    case storedImageMissing
    case storedImageCorrupted

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return
                "The Application Support folder could not be located."

        case .emptyImageData:
            return
                "The image did not contain any data."

        case .invalidImageData:
            return
                "The supplied data is not a valid image."

        case .unsupportedImageFormat:
            return
                "The image format is not supported."

        case .missingImageDimensions:
            return
                "The image dimensions could not be determined."

        case .invalidFilenameExtension:
            return
                "The image filename extension is invalid."

        case .storedImageMissing:
            return
                "The stored image file could not be found."

        case .storedImageCorrupted:
            return
                "The stored image file does not match its saved metadata."
        }
    }
}
