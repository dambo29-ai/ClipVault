//
//  ScreenshotCandidateService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation
import UniformTypeIdentifiers

struct ScreenshotCandidate:
    Equatable,
    Sendable
{
    let fileURL:
        URL

    let creationDate:
        Date

    let fileSize:
        Int
}

struct ScreenshotCandidateService:
    Sendable
{
    private let supportedFilenameExtensions:
        Set<String> =
            [
                "heic",
                "jpeg",
                "jpg",
                "png",
                "tif",
                "tiff"
            ]

    func candidate(
        for fileURL:
            URL,
        monitoringStartedAt:
            Date
    ) -> ScreenshotCandidate? {
        let standardizedURL =
            fileURL
                .standardizedFileURL

        let filename =
            standardizedURL
                .lastPathComponent

        guard
            isLikelyScreenshotFilename(
                filename
            ),
            isSupportedStillImage(
                standardizedURL
            )
        else {
            return nil
        }

        let resourceValues:
            URLResourceValues

        do {
            resourceValues =
                try standardizedURL
                    .resourceValues(
                        forKeys: [
                            .isRegularFileKey,
                            .creationDateKey,
                            .contentModificationDateKey,
                            .fileSizeKey,
                            .contentTypeKey
                        ]
                    )
        } catch {
            return nil
        }

        guard
            resourceValues
                .isRegularFile ==
                true
        else {
            return nil
        }

        guard
            let creationDate =
                resourceValues
                    .creationDate ??
                resourceValues
                    .contentModificationDate,
            creationDate >=
                monitoringStartedAt
                    .addingTimeInterval(
                        -1
                    )
        else {
            return nil
        }

        guard
            let fileSize =
                resourceValues
                    .fileSize,
            fileSize >
                0
        else {
            return nil
        }

        if let contentType =
            resourceValues
                .contentType
        {
            guard
                contentType
                    .conforms(
                        to:
                            .image
                    )
            else {
                return nil
            }
        }

        return ScreenshotCandidate(
            fileURL:
                standardizedURL,
            creationDate:
                creationDate,
            fileSize:
                fileSize
        )
    }

    func isLikelyScreenshotFilename(
        _ filename:
            String
    ) -> Bool {
        let normalizedFilename =
            filename
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        guard
            !normalizedFilename
                .isEmpty
        else {
            return false
        }

        /*
         English macOS versions currently use names
         beginning with either "Screenshot" or the older
         "Screen Shot" form.

         Screen recordings are explicitly excluded.
         */
        if normalizedFilename
            .hasPrefix(
                "screen recording"
            )
        {
            return false
        }

        return normalizedFilename
            .hasPrefix(
                "screenshot"
            ) ||
            normalizedFilename
                .hasPrefix(
                    "screen shot"
                )
    }

    func isSupportedStillImage(
        _ fileURL:
            URL
    ) -> Bool {
        supportedFilenameExtensions
            .contains(
                fileURL
                    .pathExtension
                    .lowercased()
            )
    }
}
