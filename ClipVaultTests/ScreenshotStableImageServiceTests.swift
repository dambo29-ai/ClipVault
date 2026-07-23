//
//  ScreenshotStableImageServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ScreenshotStableImageServiceTests
{
    @Test
    func returnsReadableImageAfterFileSizeStabilizes()
        async
    {
        let candidate =
            makeCandidate()

        var reportedFileSizes =
            [
                100,
                200,
                200
            ]

        let expectedImageData =
            Data(
                [1, 2, 3, 4]
            )

        let service =
            ScreenshotStableImageService(
                maximumAttempts:
                    3,
                fileSizeProvider: {
                    receivedURL in

                    #expect(
                        receivedURL ==
                            candidate
                                .fileURL
                    )

                    return reportedFileSizes
                        .removeFirst()
                },
                dataProvider: {
                    receivedURL in

                    #expect(
                        receivedURL ==
                            candidate
                                .fileURL
                    )

                    return expectedImageData
                },
                imageValidator: {
                    imageData in

                    imageData ==
                        expectedImageData
                },
                delayProvider: {
                    _ in
                }
            )

        let result =
            await service
                .stableImageData(
                    for:
                        candidate
                )

        #expect(
            result ==
                expectedImageData
        )
    }

    @Test
    func retriesWhenStableDataIsNotYetReadable()
        async
    {
        let candidate =
            makeCandidate()

        var reportedFileSizes =
            [
                100,
                100,
                100
            ]

        var validationCount =
            0

        let expectedImageData =
            Data(
                [5, 6, 7, 8]
            )

        let service =
            ScreenshotStableImageService(
                maximumAttempts:
                    2,
                fileSizeProvider: {
                    _ in

                    reportedFileSizes
                        .removeFirst()
                },
                dataProvider: {
                    _ in

                    expectedImageData
                },
                imageValidator: {
                    _ in

                    validationCount +=
                        1

                    return validationCount ==
                        2
                },
                delayProvider: {
                    _ in
                }
            )

        let result =
            await service
                .stableImageData(
                    for:
                        candidate
                )

        #expect(
            result ==
                expectedImageData
        )

        #expect(
            validationCount ==
                2
        )
    }

    @Test
    func returnsNothingWhenFileNeverStabilizes()
        async
    {
        let candidate =
            makeCandidate()

        var reportedFileSizes =
            [
                100,
                200,
                300,
                400
            ]

        let service =
            ScreenshotStableImageService(
                maximumAttempts:
                    3,
                fileSizeProvider: {
                    _ in

                    reportedFileSizes
                        .removeFirst()
                },
                dataProvider: {
                    _ in

                    Issue.record(
                        "Unstable image data must not be read."
                    )

                    return Data()
                },
                imageValidator: {
                    _ in

                    Issue.record(
                        "Unstable image data must not be validated."
                    )

                    return false
                },
                delayProvider: {
                    _ in
                }
            )

        let result =
            await service
                .stableImageData(
                    for:
                        candidate
                )

        #expect(
            result ==
                nil
        )
    }

    @Test
    func returnsNothingWhenFileDisappears()
        async
    {
        let candidate =
            makeCandidate()

        var reportedFileSizes:
            [Int?] =
                [
                    100,
                    nil
                ]

        let service =
            ScreenshotStableImageService(
                fileSizeProvider: {
                    _ in

                    reportedFileSizes
                        .removeFirst()
                },
                dataProvider: {
                    _ in

                    Issue.record(
                        "Missing image data must not be read."
                    )

                    return Data()
                },
                imageValidator: {
                    _ in

                    false
                },
                delayProvider: {
                    _ in
                }
            )

        let result =
            await service
                .stableImageData(
                    for:
                        candidate
                )

        #expect(
            result ==
                nil
        )
    }

    @Test
    func returnsNothingAfterUnreadableImageExhaustsAttempts()
        async
    {
        let candidate =
            makeCandidate()

        var reportedFileSizes =
            [
                100,
                100,
                100
            ]

        var validationCount =
            0

        let service =
            ScreenshotStableImageService(
                maximumAttempts:
                    2,
                fileSizeProvider: {
                    _ in

                    reportedFileSizes
                        .removeFirst()
                },
                dataProvider: {
                    _ in

                    Data(
                        [9, 10, 11, 12]
                    )
                },
                imageValidator: {
                    _ in

                    validationCount +=
                        1

                    return false
                },
                delayProvider: {
                    _ in
                }
            )

        let result =
            await service
                .stableImageData(
                    for:
                        candidate
                )

        #expect(
            result ==
                nil
        )

        #expect(
            validationCount ==
                2
        )
    }

    private func makeCandidate()
        -> ScreenshotCandidate
    {
        ScreenshotCandidate(
            fileURL:
                URL(
                    fileURLWithPath:
                        "/Users/TestUser/Desktop/Screenshot.png"
                )
                .standardizedFileURL,
            creationDate:
                Date(),
            fileSize:
                100
        )
    }
}
