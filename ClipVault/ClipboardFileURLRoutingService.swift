//
//  ClipboardFileURLRoutingService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/17/26.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ClipboardFileURLRoutingResult:
    Equatable
{
    let imageFileURLs: [URL]
    let fileAndFolderURLs: [URL]
    let failedURLs: [URL]
}

enum ClipboardFileURLRoutingService {
    static func route(
        _ fileURLs: [URL]
    ) -> ClipboardFileURLRoutingResult {
        var imageFileURLs: [URL] = []
        var fileAndFolderURLs: [URL] = []
        var failedURLs: [URL] = []

        for fileURL in fileURLs {
            guard fileURL.isFileURL else {
                failedURLs.append(
                    fileURL
                )

                continue
            }

            let standardizedURL =
                fileURL.standardizedFileURL

            guard
                FileManager.default.fileExists(
                    atPath:
                        standardizedURL.path
                )
            else {
                failedURLs.append(
                    fileURL
                )

                continue
            }

            let didStartAccessing =
                standardizedURL
                    .startAccessingSecurityScopedResource()

            defer {
                if didStartAccessing {
                    standardizedURL
                        .stopAccessingSecurityScopedResource()
                }
            }

            let resourceValues:
                URLResourceValues

            do {
                resourceValues =
                    try standardizedURL
                        .resourceValues(
                            forKeys: [
                                .isDirectoryKey
                            ]
                        )
            } catch {
                failedURLs.append(
                    fileURL
                )

                continue
            }

            guard
                let isDirectory =
                    resourceValues.isDirectory
            else {
                failedURLs.append(
                    fileURL
                )

                continue
            }

            if isDirectory {
                fileAndFolderURLs.append(
                    standardizedURL
                )

                continue
            }

            if isSupportedRasterImage(
                at:
                    standardizedURL
            ) {
                imageFileURLs.append(
                    standardizedURL
                )
            } else {
                fileAndFolderURLs.append(
                    standardizedURL
                )
            }
        }

        return ClipboardFileURLRoutingResult(
            imageFileURLs:
                imageFileURLs,
            fileAndFolderURLs:
                fileAndFolderURLs,
            failedURLs:
                failedURLs
        )
    }

    private static func isSupportedRasterImage(
        at fileURL: URL
    ) -> Bool {
        guard
            let imageSource =
                CGImageSourceCreateWithURL(
                    fileURL as CFURL,
                    nil
                ),
            CGImageSourceGetCount(
                imageSource
            ) > 0
        else {
            return false
        }

        guard
            let typeIdentifier =
                CGImageSourceGetType(
                    imageSource
                ) as String?
        else {
            return false
        }

        guard
            typeIdentifier !=
                UTType.pdf.identifier
        else {
            return false
        }

        return true
    }
}
