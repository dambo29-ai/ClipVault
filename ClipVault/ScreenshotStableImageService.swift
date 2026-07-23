//
//  ScreenshotStableImageService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/23/26.
//

import AppKit
import Foundation

@MainActor
final class ScreenshotStableImageService
{
    private let maximumAttempts:
        Int

    private let verificationDelay:
        Duration

    private let fileSizeProvider:
        (URL) -> Int?

    private let dataProvider:
        (URL) throws -> Data

    private let imageValidator:
        (Data) -> Bool

    private let delayProvider:
        (Duration) async -> Void

    init(
        maximumAttempts:
            Int =
                5,
        verificationDelay:
            Duration =
                .milliseconds(
                    250
                ),
        fileSizeProvider:
            @escaping (URL) -> Int? = {
                fileURL in

                let resourceValues =
                    try? fileURL
                        .resourceValues(
                            forKeys: [
                                .fileSizeKey,
                                .isRegularFileKey
                            ]
                        )

                guard
                    resourceValues?
                        .isRegularFile ==
                        true
                else {
                    return nil
                }

                return resourceValues?
                    .fileSize
            },
        dataProvider:
            @escaping (URL) throws -> Data = {
                fileURL in

                try Data(
                    contentsOf:
                        fileURL,
                    options: [
                        .mappedIfSafe
                    ]
                )
            },
        imageValidator:
            @escaping (Data) -> Bool = {
                imageData in

                NSImage(
                    data:
                        imageData
                ) !=
                    nil
            },
        delayProvider:
            @escaping (Duration) async -> Void = {
                duration in

                try? await Task
                    .sleep(
                        for:
                            duration
                    )
            }
    ) {
        self.maximumAttempts =
            max(
                1,
                maximumAttempts
            )

        self.verificationDelay =
            verificationDelay

        self.fileSizeProvider =
            fileSizeProvider

        self.dataProvider =
            dataProvider

        self.imageValidator =
            imageValidator

        self.delayProvider =
            delayProvider
    }

    func stableImageData(
        for candidate:
            ScreenshotCandidate
    ) async -> Data? {
        let fileURL =
            candidate
                .fileURL
                .standardizedFileURL

        var previousFileSize =
            fileSizeProvider(
                fileURL
            )

        for attemptIndex in
            0 ..<
            maximumAttempts
        {
            guard
                let priorFileSize =
                    previousFileSize,
                priorFileSize >
                    0
            else {
                return nil
            }

            await delayProvider(
                verificationDelay
            )

            guard
                let currentFileSize =
                    fileSizeProvider(
                        fileURL
                    ),
                currentFileSize >
                    0
            else {
                return nil
            }

            if currentFileSize ==
                priorFileSize
            {
                do {
                    let imageData =
                        try dataProvider(
                            fileURL
                        )

                    if !imageData.isEmpty,
                       imageValidator(
                            imageData
                       )
                    {
                        return imageData
                    }
                } catch {
                    /*
                     The file may still be transitioning
                     between creation and readability.
                     Continue trying while attempts remain.
                     */
                }
            }

            guard
                attemptIndex <
                    maximumAttempts -
                    1
            else {
                break
            }

            previousFileSize =
                currentFileSize
        }

        return nil
    }
}
