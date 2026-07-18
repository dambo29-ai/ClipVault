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
    
    func storeClipboardImage(
        data: Data
    ) throws -> ClipboardImagePayload {
        guard !data.isEmpty else {
            throw ClipboardImageStorageError
                .emptyImageData
        }

        let inspectedImage =
            try Self.inspectImageData(
                data
            )

        do {
            let normalizedImage =
                try Self.normalizedClipboardImage(
                    data:
                        data,
                    inspectedImage:
                        inspectedImage
                )

            return try storeImage(
                data:
                    normalizedImage.data,
                wasConverted:
                    normalizedImage.wasConverted
            )
        } catch {
            /*
             A valid clipboard image should still be stored
             when adaptive conversion unexpectedly fails.
             */
            return try storeImage(
                data:
                    data
            )
        }
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
    
    func stagedImageFileURL(
        for payload:
            ClipboardImagePayload,
        preferredFilenameStem:
            String
    ) throws -> URL {
        let imageData =
            try loadImageData(
                for:
                    payload
            )

        let safeExtension =
            try Self.validatedFilenameExtension(
                payload
                    .format
                    .filenameExtension
            )

        let safeFilenameStem =
            Self.sanitizedFilenameStem(
                preferredFilenameStem
            )

        let stagingDirectoryURL =
            try resolvedImagesDirectoryURL()
                .appendingPathComponent(
                    "Paste Exports",
                    isDirectory:
                        true
                )
                .appendingPathComponent(
                    payload
                        .storageIdentifier
                        .uuidString,
                    isDirectory:
                        true
                )

        try FileManager.default
            .createDirectory(
                at:
                    stagingDirectoryURL,
                withIntermediateDirectories:
                    true
            )

        let existingURLs =
            try FileManager.default
                .contentsOfDirectory(
                    at:
                        stagingDirectoryURL,
                    includingPropertiesForKeys:
                        nil
                )

        for existingURL in
            existingURLs
        {
            try? FileManager.default
                .removeItem(
                    at:
                        existingURL
                )
        }

        let stagedFileURL =
            stagingDirectoryURL
                .appendingPathComponent(
                    "\(safeFilenameStem).\(safeExtension)",
                    isDirectory:
                        false
                )

        try imageData.write(
            to:
                stagedFileURL,
            options:
                [.atomic]
        )

        return stagedFileURL
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
    
    private nonisolated static func sanitizedFilenameStem(
        _ value:
            String
    ) -> String {
        let invalidCharacters =
            CharacterSet(
                charactersIn:
                    "/:"
            )
            .union(
                .controlCharacters
            )

        let components =
            value.components(
                separatedBy:
                    invalidCharacters
            )

        let sanitizedValue =
            components
                .joined(
                    separator:
                        "-"
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let filenameStem =
            sanitizedValue.isEmpty
                ? "Copied Image"
                : sanitizedValue

        return String(
            filenameStem
                .prefix(
                    180
                )
        )
    }
    
    private nonisolated static func normalizedClipboardImage(
        data: Data,
        inspectedImage:
            InspectedImage
    ) throws -> NormalizedClipboardImage {
        guard
            let imageSource =
                CGImageSourceCreateWithData(
                    data as CFData,
                    nil
                ),
            let image =
                CGImageSourceCreateImageAtIndex(
                    imageSource,
                    0,
                    nil
                )
        else {
            throw ClipboardImageStorageError
                .invalidImageData
        }

        let hasTransparency =
            imageHasMeaningfulTransparency(
                image
            )

        let targetType:
            UTType =
                hasTransparency
                    ? .png
                    : .jpeg

        if inspectedImage
            .format
            .uniformTypeIdentifier ==
            targetType.identifier
        {
            return NormalizedClipboardImage(
                data:
                    data,
                wasConverted:
                    false
            )
        }

        let destinationData =
            NSMutableData()

        guard
            let destination =
                CGImageDestinationCreateWithData(
                    destinationData,
                    targetType.identifier
                        as CFString,
                    1,
                    nil
                )
        else {
            throw ClipboardImageStorageError
                .unsupportedImageFormat
        }

        let properties:
            CFDictionary?

        if targetType == .jpeg {
            properties =
                [
                    kCGImageDestinationLossyCompressionQuality:
                        0.88
                ] as CFDictionary
        } else {
            properties = nil
        }

        CGImageDestinationAddImage(
            destination,
            image,
            properties
        )

        guard
            CGImageDestinationFinalize(
                destination
            )
        else {
            throw ClipboardImageStorageError
                .unsupportedImageFormat
        }

        let normalizedData =
            destinationData as Data

        guard !normalizedData.isEmpty else {
            throw ClipboardImageStorageError
                .emptyImageData
        }

        return NormalizedClipboardImage(
            data:
                normalizedData,
            wasConverted:
                true
        )
    }

    private nonisolated static func imageHasMeaningfulTransparency(
        _ image:
            CGImage
    ) -> Bool {
        switch image.alphaInfo {
        case .none,
             .noneSkipFirst,
             .noneSkipLast:
            return false

        default:
            break
        }

        let width =
            image.width

        let height =
            image.height

        guard
            width > 0,
            height > 0,
            width <=
                Int.max / height,
            width * height <=
                Int.max / 4
        else {
            return true
        }

        let bytesPerPixel = 4
        let bytesPerRow =
            width * bytesPerPixel

        var pixelData =
            Data(
                count:
                    bytesPerRow * height
            )

        let didFindTransparency =
            pixelData.withUnsafeMutableBytes {
                rawBuffer -> Bool in

                guard
                    let baseAddress =
                        rawBuffer.baseAddress,
                    let context =
                        CGContext(
                            data:
                                baseAddress,
                            width:
                                width,
                            height:
                                height,
                            bitsPerComponent:
                                8,
                            bytesPerRow:
                                bytesPerRow,
                            space:
                                CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo:
                                CGImageAlphaInfo
                                    .premultipliedLast
                                    .rawValue
                        )
                else {
                    return true
                }

                context.draw(
                    image,
                    in:
                        CGRect(
                            x: 0,
                            y: 0,
                            width:
                                width,
                            height:
                                height
                        )
                )

                let pixels =
                    rawBuffer.bindMemory(
                        to:
                            UInt8.self
                    )

                for alphaIndex in
                    stride(
                        from: 3,
                        to:
                            pixels.count,
                        by: 4
                    )
                {
                    if pixels[alphaIndex] <
                        255
                    {
                        return true
                    }
                }

                return false
            }

        return didFindTransparency
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

private struct NormalizedClipboardImage {
    let data: Data
    let wasConverted: Bool
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
