//
//  ScreenshotProcessingServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ScreenshotProcessingServiceTests
{
    @Test
    func returnsNothingBeforeMonitoringBegins()
        async
    {
        var handledImageCount =
            0

        let discoveryService =
            ScreenshotFolderDiscoveryService(
                directoryContentsProvider: {
                    _ in

                    Issue.record(
                        "The folder must not be scanned before monitoring begins."
                    )

                    return []
                }
            )

        let service =
            ScreenshotProcessingService(
                discoveryService:
                    discoveryService,
                stableImageHandler: {
                    _,
                    _ in

                    handledImageCount +=
                        1
                }
            )

        await service
            .processFolderChange()

        #expect(
            handledImageCount ==
                0
        )
    }

    @Test
    func reportsStableScreenshotData()
        async throws
    {
        let fixture =
            try makeFixture(
                filenames: [
                    "Screenshot 2026-07-23 at 3.30.00 PM.png"
                ]
            )

        defer {
            removeFixture(
                fixture
            )
        }

        let expectedImageData =
            Data(
                [1, 2, 3, 4]
            )

        var handledCandidate:
            ScreenshotCandidate?

        var handledImageData:
            Data?

        let stableImageService =
            ScreenshotStableImageService(
                fileSizeProvider: {
                    _ in

                    100
                },
                dataProvider: {
                    _ in

                    expectedImageData
                },
                imageValidator: {
                    _ in

                    true
                },
                delayProvider: {
                    _ in
                }
            )

        let service =
            ScreenshotProcessingService(
                stableImageService:
                    stableImageService,
                stableImageHandler: {
                    candidate,
                    imageData in

                    handledCandidate =
                        candidate

                    handledImageData =
                        imageData
                }
            )

        service
            .beginMonitoring(
                folderURL:
                    fixture
                        .folderURL,
                startedAt:
                    fixture
                        .creationDate
                        .addingTimeInterval(
                            -1
                        )
            )

        await service
            .processFolderChange()

        #expect(
            handledCandidate?
                .fileURL ==
                fixture
                    .fileURLs[0]
                    .standardizedFileURL
        )

        #expect(
            handledImageData ==
                expectedImageData
        )
    }

    @Test
    func skipsUnreadableScreenshot()
        async throws
    {
        let fixture =
            try makeFixture(
                filenames: [
                    "Screenshot 2026-07-23 at 3.31.00 PM.png"
                ]
            )

        defer {
            removeFixture(
                fixture
            )
        }

        var handledImageCount =
            0

        let stableImageService =
            ScreenshotStableImageService(
                maximumAttempts:
                    1,
                fileSizeProvider: {
                    _ in

                    100
                },
                dataProvider: {
                    _ in

                    Data(
                        [5, 6, 7, 8]
                    )
                },
                imageValidator: {
                    _ in

                    false
                },
                delayProvider: {
                    _ in
                }
            )

        let service =
            ScreenshotProcessingService(
                stableImageService:
                    stableImageService,
                stableImageHandler: {
                    _,
                    _ in

                    handledImageCount +=
                        1
                }
            )

        service
            .beginMonitoring(
                folderURL:
                    fixture
                        .folderURL,
                startedAt:
                    fixture
                        .creationDate
                        .addingTimeInterval(
                            -1
                        )
            )

        await service
            .processFolderChange()

        #expect(
            handledImageCount ==
                0
        )
    }

    @Test
    func doesNotProcessSameScreenshotTwice()
        async throws
    {
        let fixture =
            try makeFixture(
                filenames: [
                    "Screenshot 2026-07-23 at 3.32.00 PM.png"
                ]
            )

        defer {
            removeFixture(
                fixture
            )
        }

        var handledImageCount =
            0

        let stableImageService =
            ScreenshotStableImageService(
                fileSizeProvider: {
                    _ in

                    100
                },
                dataProvider: {
                    _ in

                    Data(
                        [9, 10, 11, 12]
                    )
                },
                imageValidator: {
                    _ in

                    true
                },
                delayProvider: {
                    _ in
                }
            )

        let service =
            ScreenshotProcessingService(
                stableImageService:
                    stableImageService,
                stableImageHandler: {
                    _,
                    _ in

                    handledImageCount +=
                        1
                }
            )

        service
            .beginMonitoring(
                folderURL:
                    fixture
                        .folderURL,
                startedAt:
                    fixture
                        .creationDate
                        .addingTimeInterval(
                            -1
                        )
            )

        await service
            .processFolderChange()

        await service
            .processFolderChange()

        #expect(
            handledImageCount ==
                1
        )
    }

    @Test
    func processesMultipleScreenshotsInDiscoveryOrder()
        async throws
    {
        let fixture =
            try makeFixture(
                filenames: [
                    "Screenshot 2026-07-23 at 3.33.00 PM.png",
                    "Screenshot 2026-07-23 at 3.34.00 PM.png"
                ]
            )

        defer {
            removeFixture(
                fixture
            )
        }

        var handledFilenames:
            [String] =
                []

        let stableImageService =
            ScreenshotStableImageService(
                fileSizeProvider: {
                    _ in

                    100
                },
                dataProvider: {
                    _ in

                    Data(
                        [13, 14, 15, 16]
                    )
                },
                imageValidator: {
                    _ in

                    true
                },
                delayProvider: {
                    _ in
                }
            )

        let service =
            ScreenshotProcessingService(
                stableImageService:
                    stableImageService,
                stableImageHandler: {
                    candidate,
                    _ in

                    handledFilenames
                        .append(
                            candidate
                                .fileURL
                                .lastPathComponent
                        )
                }
            )

        service
            .beginMonitoring(
                folderURL:
                    fixture
                        .folderURL,
                startedAt:
                    fixture
                        .creationDate
                        .addingTimeInterval(
                            -1
                        )
            )

        await service
            .processFolderChange()

        #expect(
            handledFilenames ==
                fixture
                    .fileURLs
                    .map {
                        $0
                            .lastPathComponent
                    }
                    .sorted()
        )
    }

    @Test
    func stoppingMonitoringPreventsFurtherDiscovery()
        async throws
    {
        let fixture =
            try makeFixture(
                filenames: [
                    "Screenshot 2026-07-23 at 3.35.00 PM.png"
                ]
            )

        defer {
            removeFixture(
                fixture
            )
        }

        var handledImageCount =
            0

        let service =
            ScreenshotProcessingService(
                stableImageHandler: {
                    _,
                    _ in

                    handledImageCount +=
                        1
                }
            )

        service
            .beginMonitoring(
                folderURL:
                    fixture
                        .folderURL,
                startedAt:
                    fixture
                        .creationDate
                        .addingTimeInterval(
                            -1
                        )
            )

        service
            .stopMonitoring()

        await service
            .processFolderChange()

        #expect(
            handledImageCount ==
                0
        )
    }

    private func makeFixture(
        filenames:
            [String]
    ) throws -> ProcessingFixture {
        let folderURL =
            FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent(
                    "ScreenshotProcessingServiceTests-" +
                    UUID()
                        .uuidString,
                    isDirectory:
                        true
                )

        try FileManager
            .default
            .createDirectory(
                at:
                    folderURL,
                withIntermediateDirectories:
                    true
            )

        var fileURLs:
            [URL] =
                []

        for filename in filenames {
            let fileURL =
                folderURL
                    .appendingPathComponent(
                        filename,
                        isDirectory:
                            false
                    )

            try Data(
                [1, 2, 3, 4]
            )
            .write(
                to:
                    fileURL
            )

            fileURLs
                .append(
                    fileURL
                )
        }

        let firstFileURL =
            try #require(
                fileURLs
                    .first
            )

        let resourceValues =
            try firstFileURL
                .resourceValues(
                    forKeys: [
                        .creationDateKey,
                        .contentModificationDateKey
                    ]
                )

        let creationDate =
            resourceValues
                .creationDate ??
            resourceValues
                .contentModificationDate ??
            Date()

        return ProcessingFixture(
            folderURL:
                folderURL,
            fileURLs:
                fileURLs,
            creationDate:
                creationDate
        )
    }

    private func removeFixture(
        _ fixture:
            ProcessingFixture
    ) {
        try? FileManager
            .default
            .removeItem(
                at:
                    fixture
                        .folderURL
            )
    }

    private struct ProcessingFixture
    {
        let folderURL:
            URL

        let fileURLs:
            [URL]

        let creationDate:
            Date
    }
}
