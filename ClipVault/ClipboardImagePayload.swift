//
//  ClipboardImagePayload.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

import Foundation

struct ClipboardImageFormat:
    Codable,
    Equatable,
    Sendable
{
    let uniformTypeIdentifier: String
    let filenameExtension: String
    let displayName: String

    nonisolated init(
        uniformTypeIdentifier: String,
        filenameExtension: String,
        displayName: String
    ) {
        self.uniformTypeIdentifier =
            uniformTypeIdentifier

        self.filenameExtension =
            filenameExtension
                .trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "."
                    )
                )
                .lowercased()

        self.displayName =
            displayName
    }
}

struct ClipboardImagePayload:
    Codable,
    Equatable,
    Sendable
{
    let storageIdentifier: UUID
    let format: ClipboardImageFormat
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int
    let contentHash: String
    let originalFilename: String?
    let wasConverted: Bool

    nonisolated init(
        storageIdentifier: UUID = UUID(),
        format: ClipboardImageFormat,
        pixelWidth: Int,
        pixelHeight: Int,
        byteCount: Int,
        contentHash: String,
        originalFilename: String? = nil,
        wasConverted: Bool = false
    ) {
        self.storageIdentifier =
            storageIdentifier

        self.format =
            format

        self.pixelWidth =
            max(
                0,
                pixelWidth
            )

        self.pixelHeight =
            max(
                0,
                pixelHeight
            )

        self.byteCount =
            max(
                0,
                byteCount
            )

        self.contentHash =
            contentHash
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        let cleanedOriginalFilename =
            originalFilename?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        self.originalFilename =
            cleanedOriginalFilename?.isEmpty == false
                ? cleanedOriginalFilename
                : nil

        self.wasConverted =
            wasConverted
    }

    var displayTitle: String {
        "Copied Image"
    }

    var dimensionsText: String {
        "\(pixelWidth) × \(pixelHeight)"
    }
    
    var byteCountText: String {
        let formatter =
            ByteCountFormatter()

        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true

        return formatter.string(
            fromByteCount:
                Int64(byteCount)
        )
    }

    var rowMetadataText: String {
        [
            dimensionsText,
            format.displayName,
            byteCountText
        ]
        .joined(separator: " • ")
    }

    var storedFilename: String {
        guard
            !format.filenameExtension.isEmpty
        else {
            return storageIdentifier
                .uuidString
        }

        return
            "\(storageIdentifier.uuidString)." +
            format.filenameExtension
    }

    var searchableText: String {
        [
            displayTitle,
            dimensionsText,
            format.displayName,
            format.filenameExtension,
            originalFilename
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    var duplicateKey: String {
        "image:\(contentHash)"
    }
}
