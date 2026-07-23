//
//  ScreenshotProcessingService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation

@MainActor
final class ScreenshotProcessingService
{
    private let discoveryService:
        ScreenshotFolderDiscoveryService

    private let stableImageService:
        ScreenshotStableImageService

    private let stableImageHandler:
        (
            ScreenshotCandidate,
            Data
        ) -> Void

    private var isProcessing =
        false

    private var needsAnotherScan =
        false

    init(
        discoveryService:
            ScreenshotFolderDiscoveryService? =
                nil,
        stableImageService:
            ScreenshotStableImageService? =
                nil,
        stableImageHandler:
            @escaping (
                ScreenshotCandidate,
                Data
            ) -> Void = {
                _,
                _ in
            }
    ) {
        self.discoveryService =
            discoveryService ??
            ScreenshotFolderDiscoveryService()

        self.stableImageService =
            stableImageService ??
            ScreenshotStableImageService()

        self.stableImageHandler =
            stableImageHandler
    }

    func beginMonitoring(
        folderURL:
            URL,
        startedAt:
            Date =
                Date()
    ) {
        discoveryService
            .beginMonitoring(
                folderURL:
                    folderURL,
                startedAt:
                    startedAt
            )

        isProcessing =
            false

        needsAnotherScan =
            false
    }

    func stopMonitoring()
    {
        discoveryService
            .stopMonitoring()

        needsAnotherScan =
            false
    }

    func processFolderChange()
        async
    {
        if isProcessing {
            needsAnotherScan =
                true

            return
        }

        isProcessing =
            true

        repeat {
            needsAnotherScan =
                false

            let candidates =
                discoveryService
                    .discoverNewCandidates()

            for candidate in candidates {
                guard
                    let imageData =
                        await stableImageService
                            .stableImageData(
                                for:
                                    candidate
                            )
                else {
                    continue
                }

                stableImageHandler(
                    candidate,
                    imageData
                )
            }
        } while needsAnotherScan

        isProcessing =
            false
    }
}
