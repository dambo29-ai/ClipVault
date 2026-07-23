//
//  ScreenshotFolderDiscoveryServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ScreenshotFolderDiscoveryServiceTests
{
    @Test
    func returnsNothingBeforeMonitoringBegins()
    {
        let service =
            ScreenshotFolderDiscoveryService(
                directoryContentsProvider: {
                    _ in

                    Issue.record(
                        "The folder must not be scanned before monitoring begins."
                    )

                    return []
                }
            )

        #expect(
            service
                .discoverNewCandidates()
                .isEmpty
        )
    }

    @Test
    func discoversNewScreenshot()
        throws
    {
        let fixture =
            try makeFixture(
                filenames: [
                    "Screenshot 2026-07-23 at 2.50.00 PM.png"
                ]
            )

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotFolderDiscoveryService()

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

        let candidates =
            service
                .discoverNewCandidates()

        #expect(
            candidates.count ==
                1
        )

        #expect(
            candidates
                .first?
                .fileURL ==
                fixture
                    .fileURLs
                    .first?
                    .standardizedFileURL
        )
    }

    @Test
    func doesNotReturnSameScreenshotTwice()
        throws
    {
        let fixture =
            try makeFixture(
                filenames: [
                    "Screenshot 2026-07-23 at 2.51.00 PM.png"
                ]
            )

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotFolderDiscoveryService()

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

        #expect(
            service
                .discoverNewCandidates()
                .count ==
                1
        )

        #expect(
            service
                .discoverNewCandidates()
                .isEmpty
        )
    }

    @Test
    func ignoresUnrelatedFiles()
        throws
    {
        let fixture =
            try makeFixture(
                filenames: [
                    "Vacation Photo.png",
                    "Screen Recording 2026-07-23 at 2.52.00 PM.mov"
                ]
            )

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotFolderDiscoveryService()

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

        #expect(
            service
                .discoverNewCandidates()
                .isEmpty
        )
    }

    @Test
    func restartingMonitoringClearsDiscoveryState()
        throws
    {
        let fixture =
            try makeFixture(
                filenames: [
                    "Screenshot 2026-07-23 at 2.53.00 PM.png"
                ]
            )

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotFolderDiscoveryService()

        let startedAt =
            fixture
                .creationDate
                .addingTimeInterval(
                    -1
                )

        service
            .beginMonitoring(
                folderURL:
                    fixture
                        .folderURL,
                startedAt:
                    startedAt
            )

        #expect(
            service
                .discoverNewCandidates()
                .count ==
                1
        )

        service
            .stopMonitoring()

        service
            .beginMonitoring(
                folderURL:
                    fixture
                        .folderURL,
                startedAt:
                    startedAt
            )

        #expect(
            service
                .discoverNewCandidates()
                .count ==
                1
        )
    }

    private func makeFixture(
        filenames:
            [String]
    ) throws -> DiscoveryFixture {
        let folderURL =
            FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent(
                    "ScreenshotFolderDiscoveryServiceTests-" +
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

        return DiscoveryFixture(
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
            DiscoveryFixture
    ) {
        try? FileManager
            .default
            .removeItem(
                at:
                    fixture
                        .folderURL
            )
    }

    private struct DiscoveryFixture
    {
        let folderURL:
            URL

        let fileURLs:
            [URL]

        let creationDate:
            Date
    }
}
