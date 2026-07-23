//
//  ScreenshotCandidateServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation
import Testing
@testable import ClipVault

struct ScreenshotCandidateServiceTests
{
    @Test
    func recognizesCurrentScreenshotFilename()
        throws
    {
        let fixture =
            try makeFixture(
                filename:
                    "Screenshot 2026-07-23 at 12.45.00 PM.png"
            )

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotCandidateService()

        let candidate =
            service
                .candidate(
                    for:
                        fixture.fileURL,
                    monitoringStartedAt:
                        fixture.creationDate
                            .addingTimeInterval(
                                -1
                            )
                )

        #expect(
            candidate !=
                nil
        )

        #expect(
            candidate?
                .fileURL ==
                fixture
                    .fileURL
                    .standardizedFileURL
        )
    }

    @Test
    func recognizesLegacyScreenShotFilename()
        throws
    {
        let fixture =
            try makeFixture(
                filename:
                    "Screen Shot 2026-07-23 at 12.45.00 PM.jpg"
            )

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotCandidateService()

        #expect(
            service
                .candidate(
                    for:
                        fixture.fileURL,
                    monitoringStartedAt:
                        fixture.creationDate
                            .addingTimeInterval(
                                -1
                            )
                ) !=
                nil
        )
    }

    @Test
    func rejectsScreenRecording()
        throws
    {
        let fixture =
            try makeFixture(
                filename:
                    "Screen Recording 2026-07-23 at 12.45.00 PM.mov"
            )

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotCandidateService()

        #expect(
            service
                .candidate(
                    for:
                        fixture.fileURL,
                    monitoringStartedAt:
                        fixture.creationDate
                            .addingTimeInterval(
                                -1
                            )
                ) ==
                nil
        )
    }

    @Test
    func rejectsUnrelatedImageInScreenshotFolder()
        throws
    {
        let fixture =
            try makeFixture(
                filename:
                    "Vacation Photo.png"
            )

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotCandidateService()

        #expect(
            service
                .candidate(
                    for:
                        fixture.fileURL,
                    monitoringStartedAt:
                        fixture.creationDate
                            .addingTimeInterval(
                                -1
                            )
                ) ==
                nil
        )
    }

    @Test
    func rejectsScreenshotCreatedBeforeMonitoringStarted()
        throws
    {
        let fixture =
            try makeFixture(
                filename:
                    "Screenshot 2026-07-23 at 12.45.00 PM.png"
            )

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotCandidateService()

        #expect(
            service
                .candidate(
                    for:
                        fixture.fileURL,
                    monitoringStartedAt:
                        fixture.creationDate
                            .addingTimeInterval(
                                10
                            )
                ) ==
                nil
        )
    }

    @Test
    func rejectsUnsupportedScreenshotExtension()
        throws
    {
        let fixture =
            try makeFixture(
                filename:
                    "Screenshot 2026-07-23 at 12.45.00 PM.mov"
            )

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotCandidateService()

        #expect(
            service
                .candidate(
                    for:
                        fixture.fileURL,
                    monitoringStartedAt:
                        fixture.creationDate
                            .addingTimeInterval(
                                -1
                            )
                ) ==
                nil
        )
    }

    private func makeFixture(
        filename:
            String
    ) throws -> ScreenshotFixture {
        let directoryURL =
            FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent(
                    "ScreenshotCandidateServiceTests-" +
                    UUID()
                        .uuidString,
                    isDirectory:
                        true
                )

        try FileManager
            .default
            .createDirectory(
                at:
                    directoryURL,
                withIntermediateDirectories:
                    true
            )

        let fileURL =
            directoryURL
                .appendingPathComponent(
                    filename,
                    isDirectory:
                        false
                )

        /*
         The detector does not decode image pixels in
         this checkpoint. It validates filename, file
         type metadata, creation time, and nonzero size.
         */
        try Data(
            [1, 2, 3, 4]
        )
        .write(
            to:
                fileURL
        )

        let resourceValues =
            try fileURL
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

        return ScreenshotFixture(
            directoryURL:
                directoryURL,
            fileURL:
                fileURL,
            creationDate:
                creationDate
        )
    }

    private func removeFixture(
        _ fixture:
            ScreenshotFixture
    ) {
        try? FileManager
            .default
            .removeItem(
                at:
                    fixture
                        .directoryURL
            )
    }

    private struct ScreenshotFixture
    {
        let directoryURL:
            URL

        let fileURL:
            URL

        let creationDate:
            Date
    }
}
